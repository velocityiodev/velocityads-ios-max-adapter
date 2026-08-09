import AppLovinSDK
import VelocityAdsSDK

/// Bridges `VelocityRewardedAdDelegate` callbacks to `MARewardedAdapterDelegate`.
///
/// The Velocity SDK delivers all callbacks on the main thread (the protocol is
/// `@MainActor`), so no additional dispatching is required before forwarding to MAX.
///
/// Velocity does not supply reward metadata, so the adapter reports
/// `MAReward.defaultAmount` / `MAReward.defaultLabel` — the canonical MAX
/// convention for networks that track reward completion server-side.
@MainActor
final class VelocityRewardedAdapterDelegate: NSObject, VelocityRewardedAdDelegate {

    // MARK: - Properties

    /// The current MAX delegate. Updated on show so the correct delegate receives
    /// display-phase callbacks.
    weak var maxDelegate: MARewardedAdapterDelegate?

    /// Called after `onAdDismissed` so the owning adapter can release the ad reference.
    var onDismissed: (() -> Void)?

    // MARK: - VelocityRewardedAdDelegate / VelocityFullscreenAdDelegate

    func onAdLoaded(ad: any VelocityFullscreenAd) {
        maxDelegate?.didLoadRewardedAd()
    }

    func onAdFailedToLoad(ad: any VelocityFullscreenAd, error: VelocityAdsError) {
        maxDelegate?.didFailToLoadRewardedAdWithError(VelocityAdsErrorMapper.map(error))
    }

    func onAdShown(ad: any VelocityFullscreenAd) {
        // Surface is visible — signal MAX that the ad is displaying. MAX will then
        // fire its own impression beacon; calling didDisplay here (show time) rather
        // than in onAdImpression avoids a potential double-count.
        maxDelegate?.didDisplayRewardedAd()
    }

    func onAdImpression(ad: any VelocityFullscreenAd) {
        // Velocity impression confirmed — no additional MAX signal needed here.
    }

    func onAdFailedToShow(ad: any VelocityFullscreenAd, error: VelocityAdsError) {
        maxDelegate?.didFailToDisplayRewardedAdWithError(VelocityAdsErrorMapper.map(error))
    }

    func onAdClicked(ad: any VelocityFullscreenAd) {
        maxDelegate?.didClickRewardedAd()
    }

    /// Fires before `onAdDismissed` per the Velocity callback contract.
    func onUserRewarded(ad: any VelocityFullscreenAd) {
        let reward = MAReward(amount: MAReward.defaultAmount, label: MAReward.defaultLabel)
        maxDelegate?.didRewardUser(with: reward)
    }

    func onAdDismissed(ad: any VelocityFullscreenAd) {
        maxDelegate?.didHideRewardedAd()
        onDismissed?()
    }
}
