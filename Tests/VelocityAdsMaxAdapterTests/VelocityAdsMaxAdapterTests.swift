import AppLovinSDK
import UIKit
import VelocityAdsSDK
import XCTest

@testable import VelocityAdsMaxAdapter

// MARK: - Stub parameters

/// Minimal stub for MAAdapterInitializationParameters.
/// Implements only the properties the adapter reads; all others return safe
/// empty defaults so protocol conformance is satisfied.
private final class StubInitParameters: NSObject, MAAdapterInitializationParameters {
    private let _serverParameters: [String: Any]

    init(serverParameters: [String: Any] = [:]) {
        self._serverParameters = serverParameters
    }

    var adUnitIdentifier: String { "" }
    var localExtraParameters: [String: Any] { [:] }
    var serverParameters: [String: Any] { _serverParameters }
    var customParameters: [String: Any] { [:] }
    var userConsent: NSNumber? { nil }
    var doNotSell: NSNumber? { nil }
    var consentString: String? { nil }
    var isTesting: Bool { false }
    var presentingViewController: UIViewController? { nil }
}

/// Minimal stub for MAAdapterResponseParameters.
private final class StubResponseParameters: NSObject, MAAdapterResponseParameters {
    private let _adUnitId: String
    private let _serverParameters: [String: Any]

    init(adUnitId: String = "test-ad-unit",
         serverParameters: [String: Any] = ["app_id": "test-key"]) {
        self._adUnitId = adUnitId
        self._serverParameters = serverParameters
    }

    var adUnitIdentifier: String { "" }
    var localExtraParameters: [String: Any] { [:] }
    var serverParameters: [String: Any] { _serverParameters }
    var customParameters: [String: Any] { [:] }
    var userConsent: NSNumber? { nil }
    var doNotSell: NSNumber? { nil }
    var consentString: String? { nil }
    var isTesting: Bool { false }
    var presentingViewController: UIViewController? { nil }
    var thirdPartyAdPlacementIdentifier: String { _adUnitId }
    var bidResponse: String { "" }
    var isBidding: Bool { false }
    var bidExpirationMillis: Int64 { -1 }
}

// MARK: - Spy delegates

/// Spy for MAInterstitialAdapterDelegate. Captures the first error from each
/// failure callback for assertion; all other methods are no-ops.
private final class SpyInterstitialDelegate: NSObject, MAInterstitialAdapterDelegate {
    var failedToLoadError: MAAdapterError?
    var failedToDisplayError: MAAdapterError?

    func didLoadInterstitialAd() {}
    func didLoadInterstitialAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didFailToLoadInterstitialAdWithError(_ adapterError: MAAdapterError) { failedToLoadError = adapterError }
    func didDisplayInterstitialAd() {}
    func didDisplayInterstitialAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didClickInterstitialAd() {}
    func didClickInterstitialAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didHideInterstitialAd() {}
    func didHideInterstitialAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didFailToDisplayInterstitialAdWithError(_ adapterError: MAAdapterError) { failedToDisplayError = adapterError }
    func didFailToDisplayInterstitialAdWithError(_ adapterError: MAAdapterError, extraInfo: [String: Any]?) {}
}

/// Spy for MARewardedAdapterDelegate.
private final class SpyRewardedDelegate: NSObject, MARewardedAdapterDelegate {
    var failedToLoadError: MAAdapterError?
    var failedToDisplayError: MAAdapterError?

    func didLoadRewardedAd() {}
    func didLoadRewardedAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didFailToLoadRewardedAdWithError(_ adapterError: MAAdapterError) { failedToLoadError = adapterError }
    func didDisplayRewardedAd() {}
    func didDisplayRewardedAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didFailToDisplayRewardedAdWithError(_ adapterError: MAAdapterError) { failedToDisplayError = adapterError }
    func didFailToDisplayRewardedAdWithError(_ adapterError: MAAdapterError, extraInfo: [String: Any]?) {}
    func didClickRewardedAd() {}
    func didClickRewardedAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didHideRewardedAd() {}
    func didHideRewardedAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didRewardUser(with reward: MAReward) {}
    func didRewardUser(with reward: MAReward, extraInfo: [String: Any]?) {}
}

/// Spy for MAAdViewAdapterDelegate.
private final class SpyAdViewDelegate: NSObject, MAAdViewAdapterDelegate {
    var failedToLoadError: MAAdapterError?

    func didLoadAd(forAdView adView: UIView) {}
    func didLoadAd(forAdView adView: UIView, withExtraInfo extraInfo: [String: Any]?) {}
    func didFailToLoadAdViewAdWithError(_ adapterError: MAAdapterError) { failedToLoadError = adapterError }
    func didDisplayAdViewAd() {}
    func didDisplayAdViewAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didFailToDisplayAdViewAdWithError(_ adapterError: MAAdapterError) {}
    func didFailToDisplayAdViewAdWithError(_ adapterError: MAAdapterError, extraInfo: [String: Any]?) {}
    func didClickAdViewAd() {}
    func didClickAdViewAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didHideAdViewAd() {}
    func didHideAdViewAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didExpandAdViewAd() {}
    func didExpandAdViewAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didCollapseAdViewAd() {}
    func didCollapseAdViewAd(withExtraInfo extraInfo: [String: Any]?) {}
}

// MARK: - Tests

/// Tests for the main `VelocityAdsMaxAdapter` lifecycle, initialization guards,
/// and load-path validation.
///
/// Threading: all adapter entry points are invoked on the main thread by MAX.
/// The `@MainActor` annotation ensures `runOnMainNow` executes synchronously
/// in these tests, keeping assertions immediate rather than deferred.
@MainActor
final class VelocityAdsMaxAdapterTests: XCTestCase {

    /// Delegates handed to the stubbed initSDK runner, so tests can drive the
    /// coalesced init flow to completion deterministically.
    private var capturedInitDelegates: [VelocityAdsInitDelegate] = []

    override func setUp() {
        super.setUp()
        capturedInitDelegates = []
        // Stub the SDK init trigger: unit tests must never perform real network
        // initialization. Individual tests complete the flow via the captured
        // delegate when they need a terminal outcome.
        VelocityAdsMaxAdapter.initSDKRunnerForTesting = { [weak self] _, delegate in
            self?.capturedInitDelegates.append(delegate)
        }
    }

    override func tearDown() {
        // Unclaims the shared static coalescer and clears all test seams so
        // state cannot leak between test cases.
        VelocityAdsMaxAdapter.resetInitStateForTesting()
        capturedInitDelegates = []
        super.tearDown()
    }

    /// Completes the in-flight stubbed init with a failure outcome.
    private func failInFlightInit() {
        for delegate in capturedInitDelegates {
            delegate.onInitFailure(error: VelocityAdsError(
                code: VelocityAdsErrorCode.internalError,
                message: "test-driven init failure"
            ))
        }
        capturedInitDelegates = []
    }

    // MARK: - initialize() — synchronous guard paths

    func test_initialize_withMissingAppId_reportsInitializedUnknown() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        let params = StubInitParameters(serverParameters: [:])

        // When
        var status: MAAdapterInitializationStatus?
        adapter.initialize(with: params) { result, _ in status = result }

        // Then — the App ID field is optional at network-level init; the real
        // SDK init happens lazily on the first load via ensureInitialized().
        XCTAssertEqual(status, .initializedUnknown,
                       "Missing app_id must report initializedUnknown (lazy init on first load)")
    }

    func test_initialize_withEmptyAppId_reportsInitializedUnknown() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        let params = StubInitParameters(serverParameters: ["app_id": ""])

        // When
        var status: MAAdapterInitializationStatus?
        adapter.initialize(with: params) { result, _ in status = result }

        // Then
        XCTAssertEqual(status, .initializedUnknown,
                       "Empty app_id must report initializedUnknown (lazy init on first load)")
    }

    func test_initialize_afterDestroy_callsCompletionWithFailure() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        adapter.destroy()
        let params = StubInitParameters(serverParameters: ["app_id": "test-key"])

        // When
        var status: MAAdapterInitializationStatus?
        adapter.initialize(with: params) { result, _ in status = result }

        // Then — the isDestroyed guard fires synchronously
        XCTAssertEqual(status, .initializedFailure,
                       "A destroyed adapter must report initializedFailure immediately")
    }

    // MARK: - initialize() — coalescing

    func test_initialize_simultaneousCalls_coalesceOntoOneInitAndShareTheOutcome() {
        // Given — two adapter instances sharing the same static initCoalescer
        let adapter1 = VelocityAdsMaxAdapter()
        let adapter2 = VelocityAdsMaxAdapter()
        let params = StubInitParameters(serverParameters: ["app_id": "test-key"])

        // When — both call initialize on the main thread (synchronous dispatch)
        var outcome1: MAAdapterInitializationStatus?
        var outcome2: MAAdapterInitializationStatus?

        adapter1.initialize(with: params) { result, _ in outcome1 = result }
        adapter2.initialize(with: params) { result, _ in outcome2 = result }

        // Then — only the first caller triggers the SDK init; the second parks on
        // the coalescer instead of receiving an immediate
        // SDK_INITIALIZATION_IN_PROGRESS failure. Neither completes synchronously.
        XCTAssertEqual(capturedInitDelegates.count, 1,
                       "Exactly one SDK init must be started for coalesced concurrent calls")
        XCTAssertNil(outcome1, "First initialize handler must not fire synchronously")
        XCTAssertNil(outcome2, "Second initialize handler must not fire synchronously")

        // When — the single in-flight init resolves
        failInFlightInit()

        // Then — the outcome is broadcast to both parked handlers
        XCTAssertEqual(outcome1, .initializedFailure, "Winner must receive the broadcast outcome")
        XCTAssertEqual(outcome2, .initializedFailure, "Parked caller must receive the broadcast outcome")
    }

    func test_initialize_destroyedWhileInitInFlight_stillCompletesWithFailure() {
        // Given — an initialize whose SDK init is still in flight
        let adapter = VelocityAdsMaxAdapter()
        let params = StubInitParameters(serverParameters: ["app_id": "test-key"])

        var status: MAAdapterInitializationStatus?
        var message: String?
        adapter.initialize(with: params) { result, resultMessage in
            status = result
            message = resultMessage
        }
        XCTAssertNil(status, "Init must be pending before the SDK responds")

        // When — the adapter is destroyed mid-flight, then the init resolves
        adapter.destroy()
        failInFlightInit()

        // Then — MAX still receives exactly one completion, degraded to failure
        XCTAssertEqual(status, .initializedFailure,
                       "A destroyed adapter must still complete its MAX init handler")
        XCTAssertEqual(message, "Velocity Ads adapter was destroyed before initialization completed")
    }

    func test_initialize_winnerDestroyedMidFlight_parkedPeerStillReceivesOutcome() {
        // Given — adapter1 wins the claim, adapter2 parks on the coalescer
        let adapter1 = VelocityAdsMaxAdapter()
        let adapter2 = VelocityAdsMaxAdapter()
        let params = StubInitParameters(serverParameters: ["app_id": "test-key"])

        var outcome2: MAAdapterInitializationStatus?
        adapter1.initialize(with: params) { _, _ in }
        adapter2.initialize(with: params) { result, _ in outcome2 = result }

        // When — the winning adapter is destroyed while its init is in flight.
        // The init bridge is coalescer-scoped, so destroying the winner must not
        // strand the parked peer.
        adapter1.destroy()
        failInFlightInit()

        // Then
        XCTAssertEqual(outcome2, .initializedFailure,
                       "Parked adapter must receive the outcome even after the winner is destroyed")
    }

    // MARK: - Privacy forwarding on load

    func test_loadInterstitialAd_forwardsCurrentALPrivacySettingsOnLoad() {
        // Given — global AppLovin privacy state, as set by the publisher / CMP.
        // The adapter reads ALPrivacySettings directly (response-parameter privacy
        // fields are not reliably populated on every entry point).
        ALPrivacySettings.setHasUserConsent(false)
        ALPrivacySettings.setDoNotSell(true)

        let adapter = VelocityAdsMaxAdapter()
        let params = StubResponseParameters(adUnitId: "test-unit")
        let spy = SpyInterstitialDelegate()

        var forwardedConsent: Bool??
        var forwardedDoNotSell: Bool??
        VelocityAdsMaxAdapter.privacyForwardingObserverForTesting = { consent, doNotSell in
            forwardedConsent = consent
            forwardedDoNotSell = doNotSell
        }

        // When — a load arrives with updated CMP state
        adapter.loadInterstitialAd(for: params, andNotify: spy)

        // Then — the signals are forwarded to the SDK before the request proceeds
        XCTAssertEqual(forwardedConsent, .some(false),
                       "Mid-session consent revocation must be forwarded on load")
        XCTAssertEqual(forwardedDoNotSell, .some(true),
                       "Mid-session do-not-sell opt-out must be forwarded on load")
    }

    // MARK: - destroy() lifecycle

    func test_destroy_preventsInterstitialLoad_callsDelegateWithInvalidLoadState() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        adapter.destroy()

        let params = StubResponseParameters(adUnitId: "test-unit")
        let spy = SpyInterstitialDelegate()

        // When
        adapter.loadInterstitialAd(for: params, andNotify: spy)

        // Then — runOnMainNow executes synchronously; isDestroyed guard triggers
        XCTAssertEqual(spy.failedToLoadError?.code,
                       MAAdapterError.invalidLoadState.code,
                       "Destroyed adapter must immediately fail interstitial load with invalidLoadState")
    }

    func test_destroy_preventsRewardedLoad_callsDelegateWithInvalidLoadState() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        adapter.destroy()

        let params = StubResponseParameters(adUnitId: "test-unit")
        let spy = SpyRewardedDelegate()

        // When
        adapter.loadRewardedAd(for: params, andNotify: spy)

        // Then
        XCTAssertEqual(spy.failedToLoadError?.code,
                       MAAdapterError.invalidLoadState.code,
                       "Destroyed adapter must immediately fail rewarded load with invalidLoadState")
    }

    func test_destroy_preventsBannerLoad_callsDelegateWithInvalidLoadState() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        adapter.destroy()

        let params = StubResponseParameters(adUnitId: "test-unit")
        let spy = SpyAdViewDelegate()

        // When
        adapter.loadAdViewAd(for: params, adFormat: MAAdFormat.banner, andNotify: spy)

        // Then
        XCTAssertEqual(spy.failedToLoadError?.code,
                       MAAdapterError.invalidLoadState.code,
                       "Destroyed adapter must immediately fail banner load with invalidLoadState")
    }

    // MARK: - Load guard — empty ad unit ID

    func test_loadInterstitialAd_withEmptyAdUnitId_callsDelegateWithInvalidConfiguration() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        let params = StubResponseParameters(adUnitId: "")
        let spy = SpyInterstitialDelegate()

        // When
        adapter.loadInterstitialAd(for: params, andNotify: spy)

        // Then
        XCTAssertEqual(spy.failedToLoadError?.code,
                       MAAdapterError.invalidConfiguration.code,
                       "Empty ad unit ID must fail with invalidConfiguration")
    }

    func test_loadRewardedAd_withEmptyAdUnitId_callsDelegateWithInvalidConfiguration() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        let params = StubResponseParameters(adUnitId: "")
        let spy = SpyRewardedDelegate()

        // When
        adapter.loadRewardedAd(for: params, andNotify: spy)

        // Then
        XCTAssertEqual(spy.failedToLoadError?.code,
                       MAAdapterError.invalidConfiguration.code,
                       "Empty ad unit ID must fail with invalidConfiguration")
    }

    func test_loadBannerAd_withEmptyAdUnitId_callsDelegateWithInvalidConfiguration() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        let params = StubResponseParameters(adUnitId: "")
        let spy = SpyAdViewDelegate()

        // When
        adapter.loadAdViewAd(for: params, adFormat: MAAdFormat.banner, andNotify: spy)

        // Then
        XCTAssertEqual(spy.failedToLoadError?.code,
                       MAAdapterError.invalidConfiguration.code,
                       "Empty ad unit ID must fail with invalidConfiguration")
    }
}
