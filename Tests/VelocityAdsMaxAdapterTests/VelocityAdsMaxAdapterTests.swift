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

    init(adUnitId: String = "test-ad-unit", serverParameters: [String: Any] = ["app_key": "test-key"]) {
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

/// Spy for MANativeAdAdapterDelegate.
private final class SpyNativeDelegate: NSObject, MANativeAdAdapterDelegate {
    var failedToLoadError: MAAdapterError?

    func didLoadAd(for nativeAd: MANativeAd, withExtraInfo extraInfo: [String: Any]?) {}
    func didFailToLoadNativeAdWithError(_ adapterError: MAAdapterError) { failedToLoadError = adapterError }
    func didDisplayNativeAd(withExtraInfo extraInfo: [String: Any]?) {}
    func didClickNativeAd() {}
    func didClickNativeAd(withExtraInfo extraInfo: [String: Any]?) {}
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

    // MARK: - initialize() — synchronous guard paths

    func test_initialize_withMissingAppKey_callsCompletionWithFailure() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        let params = StubInitParameters(serverParameters: [:])

        // When
        var status: MAAdapterInitializationStatus?
        adapter.initialize(with: params) { s, _ in status = s }

        // Then
        XCTAssertEqual(status, .initializedFailure,
                       "Missing app_key must produce an immediate initializedFailure")
    }

    func test_initialize_withEmptyAppKey_callsCompletionWithFailure() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        let params = StubInitParameters(serverParameters: ["app_key": ""])

        // When
        var status: MAAdapterInitializationStatus?
        adapter.initialize(with: params) { s, _ in status = s }

        // Then
        XCTAssertEqual(status, .initializedFailure,
                       "Empty app_key must produce an immediate initializedFailure")
    }

    func test_initialize_afterDestroy_callsCompletionWithFailure() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        adapter.destroy()
        let params = StubInitParameters(serverParameters: ["app_key": "test-key"])

        // When
        var status: MAAdapterInitializationStatus?
        adapter.initialize(with: params) { s, _ in status = s }

        // Then — the isDestroyed guard inside runOnMainNow fires synchronously
        XCTAssertEqual(status, .initializedFailure,
                       "A destroyed adapter must report initializedFailure immediately")
    }

    // MARK: - initialize() — coalescing

    func test_initialize_simultaneousCalls_neitherHandlerCalledSynchronously() {
        // Given — two adapter instances sharing the same static initCoalescer
        let adapter1 = VelocityAdsMaxAdapter()
        let adapter2 = VelocityAdsMaxAdapter()
        let params = StubInitParameters(serverParameters: ["app_key": "test-key"])

        // When — both call initialize on the main thread (synchronous dispatch)
        var outcome1: MAAdapterInitializationStatus?
        var outcome2: MAAdapterInitializationStatus?

        adapter1.initialize(with: params) { s, _ in outcome1 = s }
        adapter2.initialize(with: params) { s, _ in outcome2 = s }

        // Then — neither completion handler is called synchronously.
        // Both are parked in the shared InitCoalescer waiting for the async
        // VelocityAds.initSDK result, which confirms coalescing is in effect:
        // the second call did not receive an immediate SDK_INITIALIZATION_IN_PROGRESS
        // failure, which would have been the outcome if it bypassed the coalescer
        // and called initSDK independently while the first call was still in flight.
        XCTAssertNil(outcome1, "First initialize handler must not fire synchronously")
        XCTAssertNil(outcome2, "Second initialize handler must not fire synchronously")
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

    func test_destroy_preventsNativeLoad_callsDelegateWithInvalidLoadState() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        adapter.destroy()

        let params = StubResponseParameters(adUnitId: "test-unit")
        let spy = SpyNativeDelegate()

        // When
        adapter.loadNativeAd(for: params, andNotify: spy)

        // Then
        XCTAssertEqual(spy.failedToLoadError?.code,
                       MAAdapterError.invalidLoadState.code,
                       "Destroyed adapter must immediately fail native load with invalidLoadState")
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

    func test_loadNativeAd_withEmptyAdUnitId_callsDelegateWithInvalidConfiguration() {
        // Given
        let adapter = VelocityAdsMaxAdapter()
        let params = StubResponseParameters(adUnitId: "")
        let spy = SpyNativeDelegate()

        // When
        adapter.loadNativeAd(for: params, andNotify: spy)

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
