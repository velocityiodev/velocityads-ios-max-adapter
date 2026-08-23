import AppLovinSDK
import Foundation
import UIKit
import VelocityAdsSDK

// MARK: - VelocityAdsMaxAdapter

/// AppLovin MAX custom-network adapter for the Velocity Ads iOS SDK.
///
/// Register this class in the MAX dashboard under **Manage Networks → Custom SDK Network**
/// with iOS class name `VelocityAdsMaxAdapter`. Set `app_key` in the **Server Side**
/// parameters for the custom network. Per-placement ad unit IDs are supplied through
/// the placement's **App ID / Placement ID** field.
///
/// Supported ad formats: Interstitial, Rewarded, Native, Banner / MREC / Leaderboard.
@objc(VelocityAdsMaxAdapter)
public final class VelocityAdsMaxAdapter: ALMediationAdapter,
                                           MAInterstitialAdapter,
                                           MARewardedAdapter,
                                           MANativeAdAdapter,
                                           MAAdViewAdapter {

    // MARK: - Private state — interstitial

    private var interstitialAd: VelocityInterstitialAd?
    private var interstitialAdDelegate: VelocityInterstitialAdapterDelegate?

    // MARK: - Private state — rewarded

    private var rewardedAd: VelocityRewardedAd?
    private var rewardedAdDelegate: VelocityRewardedAdapterDelegate?

    // MARK: - Private state — native

    private var nativeAd: VelocityNativeAd?
    private var nativeAdDelegate: VelocityNativeAdapterDelegate?

    // MARK: - Private state — banner

    private var bannerAd: VelocityBannerAd?
    private var bannerAdView: VelocityBannerAdView?
    private var bannerAdDelegate: VelocityBannerAdapterDelegate?

    // MARK: - Private state — init

    /// Held strongly so the delegate is alive for the duration of async SDK initialisation.
    private var pendingInitDelegate: VelocityAdsInitBridge?

    /// Set to `true` in `destroy()` so any queued async blocks can bail out early.
    ///
    /// Thread-safety: AppLovin MAX guarantees that all adapter lifecycle methods
    /// (`initialize`, `destroy`, `loadInterstitialAd`, etc.) are called from the
    /// main thread. `isDestroyed` is written in `destroy()` and read inside
    /// main-thread blocks — both happen on the main thread (serial), so no
    /// additional synchronisation is required.
    private var isDestroyed = false

    // MARK: - Class-level init coalescing (main-actor-confined)

    private typealias InitOutcome = (status: MAAdapterInitializationStatus, message: String?)

    /// Coalesces concurrent `VelocityAds.initSDK` attempts across adapter instances:
    /// only the first caller performs the SDK call; everyone else parks a handler
    /// and receives the winner's broadcast. This prevents the SDK from rejecting
    /// the second call with SDK_INITIALIZATION_IN_PROGRESS and MAX from treating
    /// that rejection as a permanent network failure.
    @MainActor
    private static let initCoalescer = InitCoalescer<InitOutcome>()

    // MARK: - ALMediationAdapter overrides

    public override var sdkVersion: String {
        VelocityAds.getSdkVersion()
    }

    public override var adapterVersion: String {
        velocityAdsMaxAdapterVersion
    }

    public override func initialize(
        with parameters: MAAdapterInitializationParameters,
        completionHandler: @escaping (MAAdapterInitializationStatus, String?) -> Void
    ) {
        // Privacy must be forwarded before the SDK is initialised.
        forwardPrivacySettings(from: parameters)

        // Fast path — SDK already up.
        if VelocityAds.isInitialized() {
            completionHandler(.initializedSuccess, nil)
            return
        }

        guard let appKey = parameters.serverParameters["app_key"] as? String,
              !appKey.isEmpty else {
            completionHandler(.initializedFailure,
                              "Velocity Ads: missing or empty 'app_key' in server parameters")
            return
        }

        // initSDK must be called on the main thread because VelocityAdsInitDelegate
        // is a @MainActor protocol. The bridge is created inside the block so its
        // @MainActor initialiser runs on the correct actor.
        runOnMainNow { [weak self] in
            guard let self else {
                // Adapter was released before the block ran. MAX no longer holds
                // a reference to this adapter, so calling completionHandler would
                // deliver a result to an already-orphaned context — signal failure
                // so MAX can clean up the pending init on its side.
                completionHandler(.initializedFailure,
                                  "Velocity Ads adapter was released before initialization completed")
                return
            }
            guard !self.isDestroyed else {
                // destroy() was called before this block ran. Signal failure so
                // MAX does not wait indefinitely for a completion that will never
                // arrive via the SDK delegate path.
                completionHandler(.initializedFailure,
                                  "Velocity Ads adapter was destroyed before initialization completed")
                return
            }
            // Re-check: another adapter instance may have finished SDK init in the
            // meantime (concurrent initialize() calls from MAX).
            if VelocityAds.isInitialized() {
                completionHandler(.initializedSuccess, nil)
                return
            }
            let won = VelocityAdsMaxAdapter.initCoalescer.claim { [weak self] outcome in
                // Guard against delivering a completion to an adapter that was
                // destroyed while its init was in flight or coalesced.
                guard self?.isDestroyed != true else { return }
                completionHandler(outcome.status, outcome.message)
            }
            if won {
                self.startClaimedInit(appKey: appKey)
            }
        }
    }

    public override func destroy() {
        isDestroyed = true

        // Release the init bridge first so any in-flight SDK initialisation
        // no longer delivers its completion callback to a destroyed adapter.
        pendingInitDelegate = nil

        interstitialAd?.destroy()
        interstitialAd = nil
        interstitialAdDelegate = nil

        rewardedAd?.destroy()
        rewardedAd = nil
        rewardedAdDelegate = nil

        bannerAd?.destroy()
        bannerAd = nil
        bannerAdView = nil
        bannerAdDelegate = nil

        // Strong self capture is deliberate: it keeps the adapter alive until the
        // native teardown has actually run should destroy() ever arrive off-main.
        runOnMainNow {
            self.tearDownNativeAd()
        }
    }

    // MARK: - MAInterstitialAdapter

    public func loadInterstitialAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MAInterstitialAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToLoadInterstitialAdWithError(MAAdapterError.invalidLoadState)
                return
            }

            let adUnitId = parameters.thirdPartyAdPlacementIdentifier
            guard !adUnitId.isEmpty else {
                delegate.didFailToLoadInterstitialAdWithError(MAAdapterError.invalidConfiguration)
                return
            }

            self.ensureInitialized(with: parameters) { [weak self] initialized in
                guard let self, !self.isDestroyed else {
                    delegate.didFailToLoadInterstitialAdWithError(MAAdapterError.invalidLoadState)
                    return
                }
                guard initialized else {
                    delegate.didFailToLoadInterstitialAdWithError(MAAdapterError.notInitialized)
                    return
                }

                self.interstitialAd?.destroy()
                self.interstitialAd = nil

                let adDelegate = VelocityInterstitialAdapterDelegate()
                adDelegate.maxDelegate = delegate
                adDelegate.onDismissed = { [weak self] in
                    self?.interstitialAd?.destroy()
                    self?.interstitialAd = nil
                    self?.interstitialAdDelegate = nil
                }

                let request = VelocityInterstitialAdRequest.Builder(adUnitId: adUnitId).build()
                let ad = VelocityInterstitialAd(request)

                self.interstitialAd = ad
                self.interstitialAdDelegate = adDelegate

                ad.load(delegate: adDelegate)
            }
        }
    }

    public func showInterstitialAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MAInterstitialAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToDisplayInterstitialAdWithError(MAAdapterError.invalidLoadState)
                return
            }
            guard let ad = self.interstitialAd, ad.isReady else {
                delegate.didFailToDisplayInterstitialAdWithError(MAAdapterError.adNotReady)
                return
            }

            // Refresh the delegate pointer so display-phase events reach the correct
            // MAInterstitialAdapterDelegate instance, then show.
            self.interstitialAdDelegate?.maxDelegate = delegate
            ad.show()
        }
    }

    // MARK: - MARewardedAdapter

    public func loadRewardedAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MARewardedAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToLoadRewardedAdWithError(MAAdapterError.invalidLoadState)
                return
            }

            let adUnitId = parameters.thirdPartyAdPlacementIdentifier
            guard !adUnitId.isEmpty else {
                delegate.didFailToLoadRewardedAdWithError(MAAdapterError.invalidConfiguration)
                return
            }

            self.ensureInitialized(with: parameters) { [weak self] initialized in
                guard let self, !self.isDestroyed else {
                    delegate.didFailToLoadRewardedAdWithError(MAAdapterError.invalidLoadState)
                    return
                }
                guard initialized else {
                    delegate.didFailToLoadRewardedAdWithError(MAAdapterError.notInitialized)
                    return
                }

                self.rewardedAd?.destroy()
                self.rewardedAd = nil

                let adDelegate = VelocityRewardedAdapterDelegate()
                adDelegate.maxDelegate = delegate
                adDelegate.onDismissed = { [weak self] in
                    self?.rewardedAd?.destroy()
                    self?.rewardedAd = nil
                    self?.rewardedAdDelegate = nil
                }

                let request = VelocityRewardedAdRequest.Builder(adUnitId: adUnitId).build()
                let ad = VelocityRewardedAd(request)

                self.rewardedAd = ad
                self.rewardedAdDelegate = adDelegate

                ad.load(delegate: adDelegate)
            }
        }
    }

    public func showRewardedAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MARewardedAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToDisplayRewardedAdWithError(MAAdapterError.invalidLoadState)
                return
            }
            guard let ad = self.rewardedAd, ad.isReady else {
                delegate.didFailToDisplayRewardedAdWithError(MAAdapterError.adNotReady)
                return
            }

            // Refresh the delegate pointer so display-phase events reach the correct
            // MARewardedAdapterDelegate instance, then show.
            self.rewardedAdDelegate?.maxDelegate = delegate
            ad.show()
        }
    }

    // MARK: - MANativeAdAdapter

    public func loadNativeAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MANativeAdAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToLoadNativeAdWithError(MAAdapterError.invalidLoadState)
                return
            }

            let adUnitId = parameters.thirdPartyAdPlacementIdentifier
            guard !adUnitId.isEmpty else {
                delegate.didFailToLoadNativeAdWithError(MAAdapterError.invalidConfiguration)
                return
            }

            self.ensureInitialized(with: parameters) { [weak self] initialized in
                guard let self, !self.isDestroyed else {
                    delegate.didFailToLoadNativeAdWithError(MAAdapterError.invalidLoadState)
                    return
                }
                guard initialized else {
                    delegate.didFailToLoadNativeAdWithError(MAAdapterError.notInitialized)
                    return
                }

                self.tearDownNativeAd()

                let adDelegate = VelocityNativeAdapterDelegate()
                adDelegate.maxDelegate = delegate

                let request = VelocityNativeAdRequest.Builder(adUnitId: adUnitId).build()
                let ad = VelocityNativeAd(request)

                self.nativeAd = ad
                self.nativeAdDelegate = adDelegate

                ad.load(delegate: adDelegate)
            }
        }
    }

    // MARK: - MAAdViewAdapter

    public func loadAdViewAd(
        for parameters: MAAdapterResponseParameters,
        adFormat: MAAdFormat,
        andNotify delegate: MAAdViewAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToLoadAdViewAdWithError(MAAdapterError.invalidLoadState)
                return
            }

            let adUnitId = parameters.thirdPartyAdPlacementIdentifier
            guard !adUnitId.isEmpty else {
                delegate.didFailToLoadAdViewAdWithError(MAAdapterError.invalidConfiguration)
                return
            }

            self.ensureInitialized(with: parameters) { [weak self] initialized in
                guard let self, !self.isDestroyed else {
                    delegate.didFailToLoadAdViewAdWithError(MAAdapterError.invalidLoadState)
                    return
                }
                guard initialized else {
                    delegate.didFailToLoadAdViewAdWithError(MAAdapterError.notInitialized)
                    return
                }

                self.bannerAd?.destroy()
                self.bannerAd = nil
                self.bannerAdView = nil
                self.bannerAdDelegate = nil

                let screenWidth: CGFloat
                if #available(iOS 16.0, *) {
                    screenWidth = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.screen.bounds.width ?? UIScreen.main.bounds.width
                } else {
                    screenWidth = UIScreen.main.bounds.width
                }
                let size = VelocityAdsMaxAdapter.resolveBannerSize(
                    serverParameters: parameters.serverParameters,
                    localExtraParameters: parameters.localExtraParameters,
                    adFormat: adFormat,
                    fallbackWidth: screenWidth
                )

                let adView = VelocityBannerAdView()
                self.bannerAdView = adView

                let adDelegate = VelocityBannerAdapterDelegate(maxDelegate: delegate, adView: adView)
                self.bannerAdDelegate = adDelegate

                let request = VelocityBannerAdRequest.Builder(adUnitId: adUnitId, adSize: size).build()
                let ad = VelocityBannerAd(request)
                self.bannerAd = ad

                ad.load(bannerView: adView, delegate: adDelegate)
            }
        }
    }

    // MARK: - Main-thread helpers

    /// Executes `block` on the main actor — inline when already on the main
    /// thread, otherwise deferred via `DispatchQueue.main.async`.
    ///
    /// AppLovin MAX documents that all adapter entry points are invoked on the
    /// main thread, so the inline path is the norm. The async fallback exists so
    /// an off-main call degrades to deferred execution instead of trapping in
    /// `MainActor.assumeIsolated`.
    private func runOnMainNow(_ block: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(block)
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated(block)
            }
        }
    }

    // MARK: - Native teardown

    /// Tears down the current native ad: marks the `MANativeAd` wrapper as
    /// destroyed first so `prepare(forInteractionClickableViews:)` returns
    /// `false` if MAX re-invokes it on the now-dead ad, then destroys the
    /// Velocity ad and releases both references. Shared by `destroy()` and the
    /// re-load path in `loadNativeAd` so the two cannot drift.
    @MainActor
    private func tearDownNativeAd() {
        nativeAdDelegate?.currentMaxNativeAd?.isAdDestroyed = true
        nativeAd?.destroy()
        nativeAd = nil
        nativeAdDelegate = nil
    }

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
    private func ensureInitialized(
        with parameters: MAAdapterResponseParameters,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        if VelocityAds.isInitialized() {
            completion(true)
            return
        }

        guard let appKey = parameters.serverParameters["app_key"] as? String,
              !appKey.isEmpty else {
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
    private func startClaimedInit(appKey: String) {
        let request = VelocityAdsInitRequest.Builder(appKey).build()
        let bridge = VelocityAdsInitBridge(
            onSuccess: { [weak self] in
                self?.pendingInitDelegate = nil
                VelocityAdsMaxAdapter.initCoalescer.complete(with: (.initializedSuccess, nil))
            },
            onFailure: { [weak self] error in
                self?.pendingInitDelegate = nil
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
        pendingInitDelegate = bridge
        VelocityAds.initSDK(request, delegate: bridge)
    }

    // MARK: - Privacy helpers

    private func forwardPrivacySettings(from parameters: MAAdapterInitializationParameters) {
        if let consent = parameters.userConsent {
            VelocityAds.setConsent(consent.boolValue)
        }
        if let doNotSell = parameters.doNotSell {
            VelocityAds.setDoNotSell(doNotSell.boolValue)
        }
    }
}

// MARK: - VelocityAdsInitBridge

/// Internal helper that routes `VelocityAdsInitDelegate` callbacks to the
/// adapter's init-completion logic. Kept alive as `pendingInitDelegate` on the
/// adapter. Failures are forwarded with the raw `VelocityAdsError` so the
/// caller can distinguish transient states (e.g. SDK_INITIALIZATION_IN_PROGRESS)
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
