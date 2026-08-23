import AppLovinSDK
import VelocityAdsSDK

/// Bridges `VelocityBannerAdDelegate` callbacks to `MAAdViewAdapterDelegate`.
///
/// The Velocity SDK delivers all callbacks on the main thread (the protocol is
/// `@MainActor`), so no additional dispatching is required before forwarding to MAX.
@MainActor
final class VelocityBannerAdapterDelegate: NSObject, VelocityBannerAdDelegate {

    // MARK: - Properties

    private weak var maxDelegate: MAAdViewAdapterDelegate?
    private let adView: VelocityBannerAdView

    // MARK: - Init

    init(maxDelegate: MAAdViewAdapterDelegate, adView: VelocityBannerAdView) {
        self.maxDelegate = maxDelegate
        self.adView = adView
    }

    // MARK: - VelocityBannerAdDelegate

    func onAdLoaded(ad: VelocityBannerAd) {
        maxDelegate?.didLoadAd(forAdView: adView)
    }

    func onAdFailedToLoad(ad: VelocityBannerAd, error: VelocityAdsError) {
        maxDelegate?.didFailToLoadAdViewAdWithError(VelocityAdsErrorMapper.map(error))
    }

    func onAdImpression(ad: VelocityBannerAd) {
        maxDelegate?.didDisplayAdViewAd()
    }

    func onAdClicked(ad: VelocityBannerAd) {
        maxDelegate?.didClickAdViewAd()
    }

    func onAdFailedToShow(ad: VelocityBannerAd, error: VelocityAdsError) {
        maxDelegate?.didFailToDisplayAdViewAdWithError(VelocityAdsErrorMapper.map(error))
    }
}
