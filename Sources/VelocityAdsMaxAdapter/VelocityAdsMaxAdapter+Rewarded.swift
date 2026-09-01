import AppLovinSDK
import VelocityAdsSDK

// MARK: - MARewardedAdapter

extension VelocityAdsMaxAdapter: MARewardedAdapter {

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
            //
            // parameters.presentingViewController is deliberately not forwarded —
            // the SDK's own topmost-VC resolution handles presentation instead.
            self.rewardedAdDelegate?.maxDelegate = delegate
            ad.show()
        }
    }
}
