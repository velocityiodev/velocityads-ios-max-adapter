import XCTest

@testable import VelocityAdsMaxAdapter

/// Tests for `VelocityNativeAdapterDelegate.mainImageURL` — the square-then-hero
/// main-image selection used when building the `MANativeAd` for MAX.
final class MainImageSelectionTests: XCTestCase {

    private static let squareUrl = "https://cdn.example.com/square.png"
    private static let heroUrl = "https://cdn.example.com/hero.png"

    func test_mainImageURL_prefersSquareWhenBothPresent() {
        // When
        let url = VelocityNativeAdapterDelegate.mainImageURL(squareImageUrl: Self.squareUrl,
                                                             largeImageUrl: Self.heroUrl)

        // Then
        XCTAssertEqual(url, URL(string: Self.squareUrl))
    }

    func test_mainImageURL_nilSquare_fallsBackToHero() {
        // When
        let url = VelocityNativeAdapterDelegate.mainImageURL(squareImageUrl: nil,
                                                             largeImageUrl: Self.heroUrl)

        // Then
        XCTAssertEqual(url, URL(string: Self.heroUrl))
    }

    func test_mainImageURL_emptySquare_fallsBackToHero() {
        // Given — server delivered an empty string rather than omitting the field
        // When
        let url = VelocityNativeAdapterDelegate.mainImageURL(squareImageUrl: "",
                                                             largeImageUrl: Self.heroUrl)

        // Then — the empty square must not mask the available hero image
        XCTAssertEqual(url, URL(string: Self.heroUrl))
    }

    func test_mainImageURL_bothAbsentOrEmpty_returnsNil() {
        XCTAssertNil(VelocityNativeAdapterDelegate.mainImageURL(squareImageUrl: nil,
                                                                largeImageUrl: nil))
        XCTAssertNil(VelocityNativeAdapterDelegate.mainImageURL(squareImageUrl: "",
                                                                largeImageUrl: ""))
    }
}
