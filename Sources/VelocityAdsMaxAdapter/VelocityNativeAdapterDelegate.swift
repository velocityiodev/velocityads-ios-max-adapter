import AppLovinSDK
import VelocityAdsSDK

/// Bridges `VelocityNativeAdDelegate` callbacks to `MANativeAdAdapterDelegate`.
///
/// The Velocity SDK delivers all callbacks on the main thread (the protocol is
/// `@MainActor`), so no additional dispatching is required before forwarding to MAX.
@MainActor
final class VelocityNativeAdapterDelegate: NSObject, VelocityNativeAdDelegate {

    // MARK: - Properties

    weak var maxDelegate: MANativeAdAdapterDelegate?

    /// The `VelocityMaxNativeAd` most recently delivered to MAX via `didLoadAd`.
    /// Retained so the adapter can set `isAdDestroyed = true` before calling
    /// `VelocityNativeAd.destroy()`, preventing MAX from treating the ad as
    /// still tracked after destruction.
    private(set) var currentMaxNativeAd: VelocityMaxNativeAd?

    // MARK: - VelocityNativeAdDelegate

    func onAdLoaded(nativeAd: VelocityNativeAd) {
        guard let data = nativeAd.data else {
            maxDelegate?.didFailToLoadNativeAdWithError(MAAdapterError.invalidConfiguration)
            return
        }

        var iconImage: MANativeAdImage?
        if !data.advertiserIconUrl.isEmpty,
           let iconURL = URL(string: data.advertiserIconUrl) {
            iconImage = MANativeAdImage(url: iconURL)
        }

        // Prefer the square variant (works in both portrait and landscape MAX templates);
        // fall back to the landscape hero if only that is available.
        var mainImage: MANativeAdImage?
        if let rawUrl = data.squareImageUrl ?? data.largeImageUrl,
           let mainURL = URL(string: rawUrl) {
            mainImage = MANativeAdImage(url: mainURL)
        }

        let maxNativeAd = VelocityMaxNativeAd(velocityNativeAd: nativeAd) { builder in
            builder.title        = data.title
            builder.body         = data.description
            builder.callToAction = data.callToAction
            builder.advertiser   = data.advertiserName
            builder.icon         = iconImage
            builder.mainImage    = mainImage
        }
        currentMaxNativeAd = maxNativeAd

        maxDelegate?.didLoadAd(for: maxNativeAd, withExtraInfo: nil)
    }

    func onAdFailedToLoad(nativeAd: VelocityNativeAd, error: VelocityAdsError) {
        maxDelegate?.didFailToLoadNativeAdWithError(VelocityAdsErrorMapper.map(error))
    }

    func onAdImpression(nativeAd: VelocityNativeAd) {
        maxDelegate?.didDisplayNativeAd(withExtraInfo: nil)
    }

    func onAdClicked(nativeAd: VelocityNativeAd) {
        maxDelegate?.didClickNativeAd()
    }
}
