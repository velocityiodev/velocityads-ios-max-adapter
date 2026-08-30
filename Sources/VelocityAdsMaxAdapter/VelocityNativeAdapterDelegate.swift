import AppLovinSDK
import UIKit
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
            maxDelegate?.didFailToLoadNativeAdWithError(MAAdapterError.internalError)
            return
        }

        var iconImage: MANativeAdImage?
        if !data.advertiserIconUrl.isEmpty,
           let iconURL = URL(string: data.advertiserIconUrl) {
            iconImage = MANativeAdImage(url: iconURL)
        }

        // Prefer the square variant (works in both portrait and landscape MAX templates);
        // fall back to the landscape hero. Empty strings are treated as absent so a
        // blank squareImageUrl cannot mask an available largeImageUrl.
        let mainImageURL = Self.mainImageURL(
            squareImageUrl: data.squareImageUrl,
            largeImageUrl: data.largeImageUrl
        )
        let mainImage = mainImageURL.map { MANativeAdImage(url: $0) }

        // MAX's MANativeAdView only renders `mediaView` into the publisher's media content
        // view group — it never renders `mainImage` itself — so the adapter downloads the
        // image and supplies a ready UIImageView, the same pattern AppLovin's URL-based
        // network adapters use. Download failure is non-fatal: the ad is delivered
        // without a media view.
        guard let mediaURL = mainImageURL else {
            deliverAd(nativeAd: nativeAd, data: data, iconImage: iconImage, mainImage: mainImage, mediaImage: nil)
            return
        }

        Self.fetchImage(from: mediaURL) { [weak self] image in
            guard let self else { return }
            self.deliverAd(
                nativeAd: nativeAd, data: data, iconImage: iconImage,
                mainImage: mainImage, mediaImage: image
            )
        }
    }

    /// Builds the `VelocityMaxNativeAd` and hands it to MAX. Must run on the main actor.
    private func deliverAd(
        nativeAd: VelocityNativeAd,
        data: NativeAd,
        iconImage: MANativeAdImage?,
        mainImage: MANativeAdImage?,
        mediaImage: UIImage?
    ) {
        let maxNativeAd = VelocityMaxNativeAd(velocityNativeAd: nativeAd) { builder in
            builder.title        = data.title
            builder.body         = data.description
            builder.callToAction = data.callToAction
            builder.advertiser   = data.advertiserName
            builder.icon         = iconImage
            builder.mainImage    = mainImage
            if let mediaImage {
                let imageView = UIImageView(image: mediaImage)
                imageView.contentMode = .scaleAspectFit
                imageView.clipsToBounds = true
                builder.mediaView = imageView
                if mediaImage.size.height > 0 {
                    builder.mediaContentAspectRatio = mediaImage.size.width / mediaImage.size.height
                }
            }
        }
        currentMaxNativeAd = maxNativeAd

        maxDelegate?.didLoadAd(for: maxNativeAd, withExtraInfo: nil)
    }

    /// Downloads the media image on a background URLSession and delivers the decoded
    /// `UIImage` (or `nil` on any failure) on the main actor.
    private nonisolated static func fetchImage(
        from url: URL,
        completion: @escaping @MainActor (UIImage?) -> Void
    ) {
        var request = URLRequest(url: url)
        request.timeoutInterval = mediaImageTimeoutSeconds
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let image = data.flatMap { UIImage(data: $0) }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    completion(image)
                }
            }
        }.resume()
    }

    private nonisolated static let mediaImageTimeoutSeconds: TimeInterval = 10

    func onAdFailedToLoad(nativeAd: VelocityNativeAd, error: VelocityAdsError) {
        maxDelegate?.didFailToLoadNativeAdWithError(VelocityAdsErrorMapper.map(error))
    }

    // MARK: - Main image selection

    /// Chooses the main-image URL for the MAX native template: prefer the square
    /// variant, fall back to the landscape hero. `nil` and empty-string values are
    /// both treated as absent. Pure and nonisolated so it is unit-testable.
    nonisolated static func mainImageURL(squareImageUrl: String?, largeImageUrl: String?) -> URL? {
        [squareImageUrl, largeImageUrl]
            .compactMap { $0 }
            .first { !$0.isEmpty }
            .flatMap { URL(string: $0) }
    }

    func onAdImpression(nativeAd: VelocityNativeAd) {
        maxDelegate?.didDisplayNativeAd(withExtraInfo: nil)
    }

    func onAdClicked(nativeAd: VelocityNativeAd) {
        maxDelegate?.didClickNativeAd()
    }
}
