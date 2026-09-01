import AppLovinSDK
import VelocityAdsSDK

// MARK: - MAInterstitialAdapter

extension VelocityAdsMaxAdapter: MAInterstitialAdapter {

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
            //
            // parameters.presentingViewController is deliberately not forwarded:
            // the SDK's own topmost-VC resolution handles presentation instead.
            self.interstitialAdDelegate?.maxDelegate = delegate
            ad.show()
        }
    }
}
