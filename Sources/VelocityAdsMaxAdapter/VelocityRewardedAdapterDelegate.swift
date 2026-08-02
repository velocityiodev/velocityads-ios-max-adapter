import AppLovinSDK
import VelocityAdsSDK

/// Bridges `VelocityRewardedAdDelegate` callbacks to `MARewardedAdapterDelegate`.
///
/// The Velocity SDK delivers all callbacks on the main thread (the protocol is
/// `@MainActor`), so no additional dispatching is required before forwarding to MAX.
///
/// Velocity does not supply reward metadata (amount / currency), so the adapter
/// reports `MAReward.defaultAmount` with an empty currency string — a common
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
        maxDelegate?.didFailToLoadRewardedAd(withError: VelocityAdsErrorMapper.map(error))
    }

    func onAdShown(ad: any VelocityFullscreenAd) {
        // Surface is visible — impression not yet counted. MAX display signal fires
        // in onAdImpression once the Velocity SDK has verified the impression.
    }

    func onAdImpression(ad: any VelocityFullscreenAd) {
        maxDelegate?.didDisplayRewardedAd()
    }

    func onAdFailedToShow(ad: any VelocityFullscreenAd, error: VelocityAdsError) {
        maxDelegate?.didFailToDisplayRewardedAd(withError: VelocityAdsErrorMapper.map(error))
    }

    func onAdClicked(ad: any VelocityFullscreenAd) {
        maxDelegate?.didClickRewardedAd()
    }

    /// Fires before `onAdDismissed` per the Velocity callback contract.
    func onUserRewarded(ad: any VelocityFullscreenAd) {
        let reward = MAReward(amount: MAReward.defaultAmount, currency: "")
        maxDelegate?.didRewardUser(with: reward)
    }

    func onAdDismissed(ad: any VelocityFullscreenAd) {
        maxDelegate?.didHideRewardedAd()
        onDismissed?()
    }
}
