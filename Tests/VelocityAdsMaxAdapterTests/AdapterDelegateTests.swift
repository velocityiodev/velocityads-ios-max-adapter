import AppLovinSDK
import UIKit
import VelocityAdsSDK
import XCTest

@testable import VelocityAdsMaxAdapter

// MARK: - MAX delegate spies

/// Records every MAX delegate call in order so tests can assert both the translation and
/// the ordering of Velocity callbacks.
private final class InterstitialSpy: NSObject, MAInterstitialAdapterDelegate {
    var events: [String] = []
    var lastError: MAAdapterError?

    func didLoadInterstitialAd() { events.append("load") }
    func didLoadInterstitialAd(withExtraInfo extraInfo: [String: Any]?) { events.append("load") }
    func didFailToLoadInterstitialAdWithError(_ adapterError: MAAdapterError) {
        events.append("failLoad")
        lastError = adapterError
    }
    func didDisplayInterstitialAd() { events.append("display") }
    func didDisplayInterstitialAd(withExtraInfo extraInfo: [String: Any]?) { events.append("display") }
    func didClickInterstitialAd() { events.append("click") }
    func didClickInterstitialAd(withExtraInfo extraInfo: [String: Any]?) { events.append("click") }
    func didHideInterstitialAd() { events.append("hide") }
    func didHideInterstitialAd(withExtraInfo extraInfo: [String: Any]?) { events.append("hide") }
    func didFailToDisplayInterstitialAdWithError(_ adapterError: MAAdapterError) {
        events.append("failDisplay")
        lastError = adapterError
    }
    func didFailToDisplayInterstitialAdWithError(_ adapterError: MAAdapterError, extraInfo: [String: Any]?) {
        events.append("failDisplay")
    }
}

private final class RewardedSpy: NSObject, MARewardedAdapterDelegate {
    var events: [String] = []
    var lastError: MAAdapterError?
    var reward: MAReward?

    func didLoadRewardedAd() { events.append("load") }
    func didLoadRewardedAd(withExtraInfo extraInfo: [String: Any]?) { events.append("load") }
    func didFailToLoadRewardedAdWithError(_ adapterError: MAAdapterError) {
        events.append("failLoad")
        lastError = adapterError
    }
    func didDisplayRewardedAd() { events.append("display") }
    func didDisplayRewardedAd(withExtraInfo extraInfo: [String: Any]?) { events.append("display") }
    func didFailToDisplayRewardedAdWithError(_ adapterError: MAAdapterError) {
        events.append("failDisplay")
        lastError = adapterError
    }
    func didFailToDisplayRewardedAdWithError(_ adapterError: MAAdapterError, extraInfo: [String: Any]?) {
        events.append("failDisplay")
    }
    func didClickRewardedAd() { events.append("click") }
    func didClickRewardedAd(withExtraInfo extraInfo: [String: Any]?) { events.append("click") }
    func didHideRewardedAd() { events.append("hide") }
    func didHideRewardedAd(withExtraInfo extraInfo: [String: Any]?) { events.append("hide") }
    func didRewardUser(with reward: MAReward) {
        events.append("reward")
        self.reward = reward
    }
    func didRewardUser(with reward: MAReward, extraInfo: [String: Any]?) { events.append("reward") }
}

private final class AdViewSpy: NSObject, MAAdViewAdapterDelegate {
    var events: [String] = []
    var lastError: MAAdapterError?
    var loadedView: UIView?

    func didLoadAd(forAdView adView: UIView) {
        events.append("load")
        loadedView = adView
    }
    func didLoadAd(forAdView adView: UIView, withExtraInfo extraInfo: [String: Any]?) { events.append("load") }
    func didFailToLoadAdViewAdWithError(_ adapterError: MAAdapterError) {
        events.append("failLoad")
        lastError = adapterError
    }
    func didDisplayAdViewAd() { events.append("display") }
    func didDisplayAdViewAd(withExtraInfo extraInfo: [String: Any]?) { events.append("display") }
    func didFailToDisplayAdViewAdWithError(_ adapterError: MAAdapterError) {
        events.append("failDisplay")
        lastError = adapterError
    }
    func didFailToDisplayAdViewAdWithError(_ adapterError: MAAdapterError, extraInfo: [String: Any]?) {
        events.append("failDisplay")
    }
    func didClickAdViewAd() { events.append("click") }
    func didClickAdViewAd(withExtraInfo extraInfo: [String: Any]?) { events.append("click") }
    func didHideAdViewAd() { events.append("hide") }
    func didHideAdViewAd(withExtraInfo extraInfo: [String: Any]?) { events.append("hide") }
    func didExpandAdViewAd() { events.append("expand") }
    func didExpandAdViewAd(withExtraInfo extraInfo: [String: Any]?) { events.append("expand") }
    func didCollapseAdViewAd() { events.append("collapse") }
    func didCollapseAdViewAd(withExtraInfo extraInfo: [String: Any]?) { events.append("collapse") }
}

// MARK: - Fixtures

private func makeInterstitial() -> VelocityInterstitialAd {
    VelocityInterstitialAd(VelocityInterstitialAdRequest.Builder(adUnitId: "unit-1").build())
}

private func makeRewarded() -> VelocityRewardedAd {
    VelocityRewardedAd(VelocityRewardedAdRequest.Builder(adUnitId: "unit-1").build())
}

@MainActor
private func makeBanner() -> VelocityBannerAd {
    VelocityBannerAd(VelocityBannerAdRequest.Builder(adUnitId: "unit-1", adSize: .banner).build())
}

private let noFill = VelocityAdsError(code: VelocityAdsErrorCode.noFill, message: "no fill")

// MARK: - Tests

/// Tests for the Velocity → MAX translation performed by the per-format delegates. The
/// Velocity ads are never loaded; the tests drive the delegate callbacks directly, exactly
/// as the SDK would.
@MainActor
final class VelocityInterstitialAdapterDelegateTests: XCTestCase {

    func test_fullLifecycle_translatesInOrder_andReleasesOnDismiss() {
        let spy = InterstitialSpy()
        let delegate = VelocityInterstitialAdapterDelegate()
        delegate.maxDelegate = spy
        var dismissed = 0
        delegate.onDismissed = { dismissed += 1 }
        let ad = makeInterstitial()

        delegate.onAdLoaded(ad: ad)
        delegate.onAdShown(ad: ad)
        delegate.onAdImpression(ad: ad)
        delegate.onAdClicked(ad: ad)
        delegate.onAdDismissed(ad: ad)

        XCTAssertEqual(spy.events, ["load", "display", "click", "hide"], "MAX fires its own impression on display")
        XCTAssertEqual(dismissed, 1)
    }

    func test_failures_forwardMappedErrors() {
        let spy = InterstitialSpy()
        let delegate = VelocityInterstitialAdapterDelegate()
        delegate.maxDelegate = spy
        let ad = makeInterstitial()

        delegate.onAdFailedToLoad(ad: ad, error: noFill)
        XCTAssertEqual(spy.events, ["failLoad"])
        XCTAssertEqual(spy.lastError?.code, MAAdapterError.noFill.code)
        XCTAssertEqual(spy.lastError?.mediatedNetworkErrorCode, VelocityAdsErrorCode.noFill)

        delegate.onAdFailedToShow(ad: ad, error: noFill)
        XCTAssertEqual(spy.events, ["failLoad", "failDisplay"])
    }

    func test_callbacksAfterMaxDelegateIsGone_areDropped() {
        let delegate = VelocityInterstitialAdapterDelegate()
        var dismissed = 0
        delegate.onDismissed = { dismissed += 1 }

        delegate.onAdLoaded(ad: makeInterstitial())
        delegate.onAdDismissed(ad: makeInterstitial())

        XCTAssertEqual(dismissed, 1, "Release must still happen so the creative is not leaked")
    }
}

@MainActor
final class VelocityRewardedAdapterDelegateTests: XCTestCase {

    func test_fullLifecycle_deliversDefaultRewardBeforeHide() {
        let spy = RewardedSpy()
        let delegate = VelocityRewardedAdapterDelegate()
        delegate.maxDelegate = spy
        var dismissed = 0
        delegate.onDismissed = { dismissed += 1 }
        let ad = makeRewarded()

        delegate.onAdLoaded(ad: ad)
        delegate.onAdShown(ad: ad)
        delegate.onAdImpression(ad: ad)
        delegate.onAdClicked(ad: ad)
        delegate.onUserRewarded(ad: ad)
        delegate.onAdDismissed(ad: ad)

        XCTAssertEqual(spy.events, ["load", "display", "click", "reward", "hide"])
        XCTAssertEqual(spy.reward?.amount, MAReward.defaultAmount)
        XCTAssertEqual(spy.reward?.label, MAReward.defaultLabel)
        XCTAssertEqual(dismissed, 1)
    }

    func test_failures_forwardMappedErrors() {
        let spy = RewardedSpy()
        let delegate = VelocityRewardedAdapterDelegate()
        delegate.maxDelegate = spy
        let ad = makeRewarded()

        delegate.onAdFailedToLoad(ad: ad, error: noFill)
        delegate.onAdFailedToShow(ad: ad, error: noFill)

        XCTAssertEqual(spy.events, ["failLoad", "failDisplay"])
        XCTAssertEqual(spy.lastError?.mediatedNetworkErrorCode, VelocityAdsErrorCode.noFill)
    }
}

@MainActor
final class VelocityBannerAdapterDelegateTests: XCTestCase {

    func test_lifecycle_translatesInOrder_andReportsTheHostingView() {
        let spy = AdViewSpy()
        let adView = VelocityBannerAdView(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
        let delegate = VelocityBannerAdapterDelegate(maxDelegate: spy, adView: adView)
        let ad = makeBanner()

        delegate.onAdLoaded(ad: ad)
        delegate.onAdImpression(ad: ad)
        delegate.onAdClicked(ad: ad)

        XCTAssertEqual(spy.events, ["load", "display", "click"], "Banners report display on impression")
        XCTAssertTrue(spy.loadedView === adView)
    }

    func test_failures_forwardMappedErrors() {
        let spy = AdViewSpy()
        let delegate = VelocityBannerAdapterDelegate(maxDelegate: spy, adView: VelocityBannerAdView(frame: .zero))
        let ad = makeBanner()

        delegate.onAdFailedToLoad(ad: ad, error: noFill)
        delegate.onAdFailedToShow(ad: ad, error: noFill)

        XCTAssertEqual(spy.events, ["failLoad", "failDisplay"])
        XCTAssertEqual(spy.lastError?.mediatedNetworkErrorCode, VelocityAdsErrorCode.noFill)
    }
}
