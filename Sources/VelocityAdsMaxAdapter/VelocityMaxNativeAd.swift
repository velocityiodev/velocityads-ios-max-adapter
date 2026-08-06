import AppLovinSDK
import UIKit
import VelocityAdsSDK

/// `MANativeAd` subclass that delegates view registration to the Velocity SDK.
///
/// Populate the ad assets (title, body, CTA, icon) via the builder block in the
/// initializer, exactly as you would with a plain `MANativeAd`. The SDK then calls
/// `prepare(forInteractionClickableViews:withContainer:)` when the ad view is ready
/// to be shown, at which point the container and clickable views are forwarded to
/// `VelocityNativeAd.registerViewForInteraction`.
final class VelocityMaxNativeAd: MANativeAd {

    // MARK: - Private

    private let velocityNativeAd: VelocityNativeAd

    /// Set to `true` by `VelocityAdsMaxAdapter.destroy()` (via the delegate) before
    /// `VelocityNativeAd.destroy()` is called, so `prepare(forInteractionClickableViews:)`
    /// can return `false` and prevent MAX from believing click/impression tracking is
    /// active for a destroyed ad.
    var isAdDestroyed = false

    // MARK: - Init

    /// - Parameters:
    ///   - velocityNativeAd: The loaded `VelocityNativeAd` instance.
    ///   - builderBlock: Closure that receives a `MANativeAdBuilder` to populate ad assets.
    init(velocityNativeAd: VelocityNativeAd,
         builderBlock: @escaping (MANativeAdBuilder) -> Void) {
        self.velocityNativeAd = velocityNativeAd
        super.init(format: .native, builderBlock: builderBlock)
    }

    // MARK: - MANativeAd

    @MainActor
    override func prepare(forInteractionClickableViews clickableViews: [UIView],
                          withContainer container: UIView) -> Bool {
        guard !isAdDestroyed else { return false }
        velocityNativeAd.registerViewForInteraction(adView: container,
                                                    clickableViews: clickableViews)
        return true
    }
}
