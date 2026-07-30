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
        velocityNativeAd.registerViewForInteraction(adView: container,
                                                    clickableViews: clickableViews)
        return true
    }
}
