import AppLovinSDK
import UIKit
import VelocityAdsSDK

// MARK: - MAAdViewAdapter

extension VelocityAdsMaxAdapter: MAAdViewAdapter {

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

                let size = VelocityAdsMaxAdapter.resolveBannerSize(
                    serverParameters: parameters.serverParameters,
                    localExtraParameters: parameters.localExtraParameters,
                    adFormat: adFormat,
                    fallbackWidth: self.fallbackBannerWidth()
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

    // MARK: - Banner helpers

    /// Width (pt) used for an adaptive banner when MAX supplies no explicit width.
    ///
    /// Prefers the foreground-active window scene's key window — `connectedScenes`
    /// is an unordered `Set`, so taking an arbitrary scene can pick a background
    /// or external-display scene on multi-scene apps, and the key-window width
    /// (not the screen width) is what matches the available container width in
    /// iPad Split View. Falls back through scene screen width to `UIScreen.main`.
    @MainActor
    private func fallbackBannerWidth() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
            ?? scenes.first
        guard let scene else {
            // UIScreen.main is deprecated on iOS 16+ but not removed; this branch is
            // only reached when no UIWindowScene is connected at all, which does not
            // occur on a running device. The scene path above handles all iOS 16+ cases.
            return UIScreen.main.bounds.width
        }
        if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return window.bounds.width
        }
        return scene.screen.bounds.width
    }
}
