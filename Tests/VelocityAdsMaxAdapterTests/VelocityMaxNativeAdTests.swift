import UIKit
import VelocityAdsSDK
import XCTest

@testable import VelocityAdsMaxAdapter

@MainActor
final class VelocityMaxNativeAdTests: XCTestCase {

    private func makeMaxNativeAd() -> VelocityMaxNativeAd {
        let request = VelocityNativeAdRequest.Builder(adUnitId: "test-ad-unit").build()
        let velocityNativeAd = VelocityNativeAd(request)
        return VelocityMaxNativeAd(velocityNativeAd: velocityNativeAd) { builder in
            builder.title = "Test title"
        }
    }

    func test_isAdDestroyed_defaultsToFalse() {
        // Given / When
        let maxNativeAd = makeMaxNativeAd()

        // Then
        XCTAssertFalse(maxNativeAd.isAdDestroyed)
    }

    func test_prepare_afterAdDestroyed_returnsFalse() {
        // Given
        let maxNativeAd = makeMaxNativeAd()
        maxNativeAd.isAdDestroyed = true

        // When
        let tracked = maxNativeAd.prepare(forInteractionClickableViews: [UIView()],
                                          withContainer: UIView())

        // Then
        XCTAssertFalse(tracked, "MAX must not believe tracking is active for a destroyed ad")
    }
}
