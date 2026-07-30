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

    // MARK: - VelocityNativeAdDelegate

    func onAdLoaded(nativeAd: VelocityNativeAd) {
        guard let data = nativeAd.data else {
            maxDelegate?.didFailToLoadNativeAd(withError:
                MAAdapterError(code: MAAdapterError.invalidConfiguration.code,
                               errorString: "VelocityNativeAd loaded but NativeAd data was nil")
            )
            return
        }

        var iconImage: MANativeAdImage?
        if !data.advertiserIconUrl.isEmpty,
           let iconURL = URL(string: data.advertiserIconUrl) {
            iconImage = MANativeAdImage(url: iconURL)
        }

        let maxNativeAd = VelocityMaxNativeAd(velocityNativeAd: nativeAd) { builder in
            builder.title      = data.title
            builder.body       = data.description
            builder.callToAction = data.callToAction
            builder.advertiser = data.advertiserName
            builder.icon       = iconImage
        }

        maxDelegate?.didLoadNativeAd(maxNativeAd, withExtraInfo: nil)
    }

    func onAdFailedToLoad(nativeAd: VelocityNativeAd, error: VelocityAdsError) {
        maxDelegate?.didFailToLoadNativeAd(withError: VelocityAdsErrorMapper.map(error))
    }

    func onAdImpression(nativeAd: VelocityNativeAd) {
        maxDelegate?.didDisplayNativeAd(withExtraInfo: nil)
    }

    func onAdClicked(nativeAd: VelocityNativeAd) {
        maxDelegate?.didClickNativeAd()
    }
}
