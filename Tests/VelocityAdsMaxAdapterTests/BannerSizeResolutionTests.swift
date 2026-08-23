import AppLovinSDK
import CoreGraphics
import VelocityAdsSDK
import XCTest

@testable import VelocityAdsMaxAdapter

final class BannerSizeResolutionTests: XCTestCase {

    private static let fallbackWidth: CGFloat = 400

    // MARK: - Adaptive

    func test_resolveBannerSize_adaptiveWithExplicitWidth_usesRequestedWidth() {
        // Given — adaptive gated on, explicit positive width supplied
        let serverParameters: [AnyHashable: Any] = ["adaptive_banner": true]
        let localExtraParameters: [AnyHashable: Any] = ["adaptive_banner_width": NSNumber(value: 375)]

        // When
        let size = VelocityAdsMaxAdapter.resolveBannerSize(
            serverParameters: serverParameters,
            localExtraParameters: localExtraParameters,
            adFormat: MAAdFormat.banner,
            fallbackWidth: Self.fallbackWidth
        )

        // Then
        XCTAssertEqual(size, VelocityBannerAdSize.adaptiveBanner(width: 375))
        XCTAssertEqual(size.width, 375)
    }

    func test_resolveBannerSize_adaptiveWithoutWidth_fallsBackToProvidedWidth() {
        // Given — adaptive gated on, no explicit width
        let serverParameters: [AnyHashable: Any] = ["adaptive_banner": true]

        // When
        let size = VelocityAdsMaxAdapter.resolveBannerSize(
            serverParameters: serverParameters,
            localExtraParameters: [:],
            adFormat: MAAdFormat.banner,
            fallbackWidth: Self.fallbackWidth
        )

        // Then
        XCTAssertEqual(size, VelocityBannerAdSize.adaptiveBanner(width: Self.fallbackWidth))
        XCTAssertEqual(size.width, Self.fallbackWidth)
    }

    func test_resolveBannerSize_adaptiveWithNonPositiveWidth_fallsBackToProvidedWidth() {
        // Given — adaptive gated on, but the supplied width is not positive
        let serverParameters: [AnyHashable: Any] = ["adaptive_banner": true]
        let localExtraParameters: [AnyHashable: Any] = ["adaptive_banner_width": NSNumber(value: 0)]

        // When
        let size = VelocityAdsMaxAdapter.resolveBannerSize(
            serverParameters: serverParameters,
            localExtraParameters: localExtraParameters,
            adFormat: MAAdFormat.banner,
            fallbackWidth: Self.fallbackWidth
        )

        // Then
        XCTAssertEqual(size, VelocityBannerAdSize.adaptiveBanner(width: Self.fallbackWidth))
    }

    func test_resolveBannerSize_adaptiveFlagAsString_isHonoured() {
        // Given — MAX delivered the boolean as a string
        let serverParameters: [AnyHashable: Any] = ["adaptive_banner": "true"]

        // When
        let size = VelocityAdsMaxAdapter.resolveBannerSize(
            serverParameters: serverParameters,
            localExtraParameters: [:],
            adFormat: MAAdFormat.banner,
            fallbackWidth: Self.fallbackWidth
        )

        // Then
        XCTAssertEqual(size, VelocityBannerAdSize.adaptiveBanner(width: Self.fallbackWidth))
    }

    // MARK: - Fixed formats

    func test_resolveBannerSize_mrec_returnsMrec() {
        // Given — adaptive not enabled, MREC format
        // When
        let size = VelocityAdsMaxAdapter.resolveBannerSize(
            serverParameters: [:],
            localExtraParameters: [:],
            adFormat: MAAdFormat.mrec,
            fallbackWidth: Self.fallbackWidth
        )

        // Then
        XCTAssertEqual(size, VelocityBannerAdSize.mrec)
    }

    func test_resolveBannerSize_leader_returnsLeaderboard() {
        // Given — adaptive not enabled, leaderboard format
        // When
        let size = VelocityAdsMaxAdapter.resolveBannerSize(
            serverParameters: [:],
            localExtraParameters: [:],
            adFormat: MAAdFormat.leader,
            fallbackWidth: Self.fallbackWidth
        )

        // Then
        XCTAssertEqual(size, VelocityBannerAdSize.leaderboard)
    }

    func test_resolveBannerSize_default_returnsBanner() {
        // Given — adaptive not enabled, standard banner format
        // When
        let size = VelocityAdsMaxAdapter.resolveBannerSize(
            serverParameters: [:],
            localExtraParameters: [:],
            adFormat: MAAdFormat.banner,
            fallbackWidth: Self.fallbackWidth
        )

        // Then
        XCTAssertEqual(size, VelocityBannerAdSize.banner)
    }

    func test_resolveBannerSize_widthWithoutAdaptiveFlag_ignoresWidth() {
        // Given — a width extra is present but adaptive is NOT gated on
        let localExtraParameters: [AnyHashable: Any] = ["adaptive_banner_width": NSNumber(value: 375)]

        // When
        let size = VelocityAdsMaxAdapter.resolveBannerSize(
            serverParameters: [:],
            localExtraParameters: localExtraParameters,
            adFormat: MAAdFormat.banner,
            fallbackWidth: Self.fallbackWidth
        )

        // Then — falls through to the adFormat-based size, not adaptive
        XCTAssertEqual(size, VelocityBannerAdSize.banner)
    }
}
