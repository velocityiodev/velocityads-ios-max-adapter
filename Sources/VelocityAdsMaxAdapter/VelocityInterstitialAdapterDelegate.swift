import AppLovinSDK
import VelocityAdsSDK

/// Bridges `VelocityInterstitialAdDelegate` callbacks to `MAInterstitialAdapterDelegate`.
///
/// The Velocity SDK delivers all callbacks on the main thread (the protocol is
/// `@MainActor`), so no additional dispatching is required before forwarding to MAX.
@MainActor
final class VelocityInterstitialAdapterDelegate: NSObject, VelocityInterstitialAdDelegate {

    // MARK: - Properties

    /// The current MAX delegate. Updated on show so the correct delegate receives
    /// display-phase callbacks.
    weak var maxDelegate: MAInterstitialAdapterDelegate?

    /// Called after `onAdDismissed` so the owning adapter can release the ad reference.
    var onDismissed: (() -> Void)?

    // MARK: - VelocityInterstitialAdDelegate / VelocityFullscreenAdDelegate

    func onAdLoaded(ad: any VelocityFullscreenAd) {
        maxDelegate?.didLoadInterstitialAd()
    }

    func onAdFailedToLoad(ad: any VelocityFullscreenAd, error: VelocityAdsError) {
        maxDelegate?.didFailToLoadInterstitialAdWithError(VelocityAdsErrorMapper.map(error))
    }

    func onAdShown(ad: any VelocityFullscreenAd) {
        // Surface is visible — signal MAX that the ad is displaying. MAX will then
        // fire its own impression beacon; calling didDisplay here (show time) rather
        // than in onAdImpression avoids a potential double-count.
        maxDelegate?.didDisplayInterstitialAd()
    }

    func onAdImpression(ad: any VelocityFullscreenAd) {
        // Velocity impression confirmed — no additional MAX signal needed here.
    }

    func onAdFailedToShow(ad: any VelocityFullscreenAd, error: VelocityAdsError) {
        maxDelegate?.didFailToDisplayInterstitialAdWithError(VelocityAdsErrorMapper.map(error))
    }

    func onAdClicked(ad: any VelocityFullscreenAd) {
        maxDelegate?.didClickInterstitialAd()
    }

    func onAdDismissed(ad: any VelocityFullscreenAd) {
        maxDelegate?.didHideInterstitialAd()
        onDismissed?()
    }
}
