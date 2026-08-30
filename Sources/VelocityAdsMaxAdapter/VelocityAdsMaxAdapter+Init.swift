import AppLovinSDK
import Foundation
import VelocityAdsSDK

// MARK: - Init coalescing and privacy forwarding

extension VelocityAdsMaxAdapter {

    typealias InitOutcome = (status: MAAdapterInitializationStatus, message: String?)

    /// Coalesces concurrent `VelocityAds.initSDK` attempts across adapter instances:
    /// only the first caller performs the SDK call; everyone else parks a handler
    /// and receives the winner's broadcast. This prevents the SDK from rejecting
    /// the second call with SDK_INITIALIZATION_IN_PROGRESS and MAX from treating
    /// that rejection as a permanent network failure.
    @MainActor
    static let initCoalescer = InitCoalescer<InitOutcome>()

    /// The init bridge for the currently claimed SDK init attempt.
    ///
    /// Coalescer-scoped (static) rather than instance-scoped on purpose: the SDK
    /// makes no documented promise about init-delegate retention, and this bridge's
    /// `onSuccess` / `onFailure` callbacks are the only paths that complete the
    /// shared coalescer. Tying its lifetime to the adapter instance that happened
    /// to win the claim would let `destroy()` release it mid-flight and strand
    /// every parked handler. The bridge clears this slot itself when its terminal
    /// callback fires.
    @MainActor
    private static var activeInitBridge: VelocityAdsInitBridge?

    #if DEBUG
    /// Test-only: replaces the `VelocityAds.initSDK` trigger so unit tests can
    /// drive the coalesced init flow deterministically without network I/O.
    @MainActor
    static var initSDKRunnerForTesting: ((VelocityAdsInitRequest, VelocityAdsInitDelegate) -> Void)?

    /// Test-only observation hook: receives every privacy value forwarded to the
    /// Velocity SDK (the SDK exposes no read-back API to assert against).
    static var privacyForwardingObserverForTesting: ((_ consent: Bool?, _ doNotSell: Bool?) -> Void)?

    /// Test-only: drains and unclaims the shared coalescer and clears all test
    /// seams so state cannot leak between test cases.
    @MainActor
    static func resetInitStateForTesting() {
        if initCoalescer.isClaimed {
            initCoalescer.complete(with: (.initializedFailure, "test reset"))
        }
        activeInitBridge = nil
        initSDKRunnerForTesting = nil
        privacyForwardingObserverForTesting = nil
    }
    #endif

    // MARK: - Init helpers

    /// Ensures the Velocity SDK is initialized before a load proceeds.
    ///
    /// If the SDK is already up, `completion(true)` fires synchronously. Otherwise
    /// a re-init is attempted (or coalesced onto an in-flight attempt) using the
    /// same machinery as `initialize(with:completionHandler:)`, and `completion`
    /// receives the outcome. This covers the case where the original MAX-driven
    /// init failed transiently (e.g. no connectivity at app launch) but a load
    /// arrives later when the SDK could now initialize successfully.
    @MainActor
    func ensureInitialized(
        with parameters: MAAdapterResponseParameters,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        // MAX refreshes consent / do-not-sell on its response parameters on every
        // load, so this is the right place to pick up mid-session CMP changes.
        // Forward unconditionally — even when the SDK is already initialized —
        // so a consent change between init and the first load is not silently lost.
        forwardPrivacySettings()

        // Covers the lazy-init path where network-level initialize() never saw an
        // app_id and the real SDK init happens here on the first load.
        forwardMediationInfo()

        if VelocityAds.isInitialized() {
            completion(true)
            return
        }

        guard let appKey = (parameters.serverParameters["app_id"] as? String)?.nilIfEmpty else {
            completion(false)
            return
        }

        let won = VelocityAdsMaxAdapter.initCoalescer.claim { outcome in
            completion(outcome.status == .initializedSuccess)
        }
        if won {
            startClaimedInit(appKey: appKey)
        }
    }

    /// Performs the actual `VelocityAds.initSDK` call on behalf of the caller
    /// that won the coalescer claim, broadcasting the outcome to every parked
    /// handler when the SDK responds.
    @MainActor
    func startClaimedInit(appKey: String) {
        let request = VelocityAdsInitRequest.Builder(appKey).build()
        let bridge = VelocityAdsInitBridge(
            onSuccess: {
                VelocityAdsMaxAdapter.activeInitBridge = nil
                VelocityAdsMaxAdapter.initCoalescer.complete(with: (.initializedSuccess, nil))
            },
            onFailure: { error in
                VelocityAdsMaxAdapter.activeInitBridge = nil
                if error.code == VelocityAdsErrorCode.sdkInitializationInProgress {
                    // The host app called VelocityAds.initSDK moments before the
                    // adapter did, so the SDK rejected our call. Not a permanent
                    // failure — wait for the in-flight init and report the real
                    // outcome. The claim stays held during polling so concurrent
                    // callers keep parking on the coalescer; the poller is the
                    // single remaining completer (the SDK delivers exactly one
                    // terminal callback per initSDK call, and this was it).
                    InFlightInitPoller.awaitInitialization(
                        isInitialized: { VelocityAds.isInitialized() }
                    ) { initialized in
                        let outcome: InitOutcome = initialized
                            ? (.initializedSuccess, nil)
                            : (.initializedFailure,
                               "Velocity Ads: timed out waiting for in-flight SDK initialization")
                        VelocityAdsMaxAdapter.initCoalescer.complete(with: outcome)
                    }
                    return
                }
                VelocityAdsMaxAdapter.initCoalescer.complete(
                    with: (.initializedFailure, "[\(error.code)] \(error.message)")
                )
            }
        )
        VelocityAdsMaxAdapter.activeInitBridge = bridge
        #if DEBUG
        if let runner = VelocityAdsMaxAdapter.initSDKRunnerForTesting {
            runner(request, bridge)
            return
        }
        #endif
        VelocityAds.initSDK(request, delegate: bridge)
    }

    // MARK: - Mediation info

    /// One-shot forwarding of the mediation environment (MAX) to the Velocity SDK.
    ///
    /// Executed at most once per process — the values (mediation name, adapter
    /// version, AppLovin SDK version) never change mid-session. The `static let`
    /// closure gives thread-safe once semantics for free.
    private static let mediationInfoForwardingToken: Void = {
        VelocityAdsMediationBridge.setMediationInfo(
            name: velocityAdsMediationName,
            adapterVersion: velocityAdsMaxAdapterVersion,
            sdkVersion: ALSdk.version()
        )
    }()

    /// Reports the mediation environment to the Velocity SDK so it is attached
    /// to every ad request and analytics event. Safe to call from any adapter
    /// entry point; only the first call has an effect.
    func forwardMediationInfo() {
        _ = VelocityAdsMaxAdapter.mediationInfoForwardingToken
    }

    // MARK: - Privacy helpers

    /// Forwards the current AppLovin privacy state to the Velocity SDK.
    ///
    /// Reads directly from `ALPrivacySettings` — the authoritative iOS source.
    /// `MAAdapterParameters.userConsent` / `doNotSell` are not used because they
    /// are only reliably non-nil when the publisher has already called the
    /// `ALPrivacySettings` setters *and* the MAX SDK has propagated the values
    /// into the parameter object — which is not guaranteed on every adapter entry
    /// point (and in particular is unreliable on `MAAdapterResponseParameters`).
    ///
    /// Called at `initialize` (before SDK boots) and on every ad load via
    /// `ensureInitialized`, so mid-session CMP changes propagate on the next request.
    func forwardPrivacySettings() {
        let consent: Bool? = ALPrivacySettings.isUserConsentSet() ? ALPrivacySettings.hasUserConsent() : nil
        let doNotSell: Bool? = ALPrivacySettings.isDoNotSellSet() ? ALPrivacySettings.isDoNotSell() : nil
        #if DEBUG
        VelocityAdsMaxAdapter.privacyForwardingObserverForTesting?(consent, doNotSell)
        #endif
        if let consent {
            VelocityAds.setConsent(consent)
        }
        if let doNotSell {
            VelocityAds.setDoNotSell(doNotSell)
        }
    }
}

// MARK: - VelocityAdsInitBridge

/// Internal helper that routes `VelocityAdsInitDelegate` callbacks to the
/// adapter's init-completion logic. Kept alive in the coalescer-scoped
/// `activeInitBridge` slot. Failures are forwarded with the raw `VelocityAdsError`
/// so the caller can distinguish transient states (e.g. SDK_INITIALIZATION_IN_PROGRESS)
/// from permanent failures.
///
/// Marked `@MainActor` because `VelocityAdsInitDelegate` is a `@MainActor` protocol.
@MainActor
private final class VelocityAdsInitBridge: NSObject, VelocityAdsInitDelegate {

    private let onSuccess: () -> Void
    private let onFailure: (VelocityAdsError) -> Void

    init(onSuccess: @escaping () -> Void, onFailure: @escaping (VelocityAdsError) -> Void) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }

    func onInitSuccess() {
        onSuccess()
    }

    func onInitFailure(error: VelocityAdsError) {
        onFailure(error)
    }
}
