import AppLovinSDK
import VelocityAdsSDK
import XCTest

@testable import VelocityAdsMaxAdapter

final class VelocityAdsErrorMapperTests: XCTestCase {

    private static let testMessage = "test error message"

    /// Every `VelocityAdsErrorCode` constant and the `MAAdapterError` prototype
    /// it must map to.
    private static let expectedMappings: [(velocityCode: Int, prototype: MAAdapterError)] = [
        // Network / HTTP layer
        (VelocityAdsErrorCode.invalidURL, MAAdapterError.badRequest),
        (VelocityAdsErrorCode.networkError, MAAdapterError.noConnection),
        (VelocityAdsErrorCode.jsonParseError, MAAdapterError.badRequest),
        (VelocityAdsErrorCode.invalidResponse, MAAdapterError.badRequest),
        (VelocityAdsErrorCode.emptyResponseBody, MAAdapterError.badRequest),
        (VelocityAdsErrorCode.serverErrorField, MAAdapterError.serverError),
        (VelocityAdsErrorCode.httpFailure, MAAdapterError.serverError),

        // SDK init / configuration
        (VelocityAdsErrorCode.invalidAppKey, MAAdapterError.invalidConfiguration),
        (VelocityAdsErrorCode.sdkNotInitialized, MAAdapterError.notInitialized),
        (VelocityAdsErrorCode.sdkInitializationInProgress, MAAdapterError.notInitialized),

        // Load lifecycle
        (VelocityAdsErrorCode.loadAlreadyInProgress, MAAdapterError.invalidLoadState),
        (VelocityAdsErrorCode.loadServiceUnavailable, MAAdapterError.notInitialized),
        (VelocityAdsErrorCode.invalidAdResponse, MAAdapterError.badRequest),
        (VelocityAdsErrorCode.noFill, MAAdapterError.noFill),
        (VelocityAdsErrorCode.internalError, MAAdapterError.internalError),
        (VelocityAdsErrorCode.adAlreadyLoaded, MAAdapterError.invalidLoadState),
        (VelocityAdsErrorCode.waterfallLoadFailed, MAAdapterError.internalError),
        (VelocityAdsErrorCode.adDestroyed, MAAdapterError.invalidLoadState),
        (VelocityAdsErrorCode.invalidAdUnitId, MAAdapterError.invalidConfiguration),
        (VelocityAdsErrorCode.adSpent, MAAdapterError.adExpiredError)
    ]

    func test_map_everyKnownCode_mapsToExpectedPrototype() {
        for (velocityCode, prototype) in Self.expectedMappings {
            // Given
            let error = VelocityAdsError(code: velocityCode, message: Self.testMessage)

            // When
            let mapped = VelocityAdsErrorMapper.map(error)

            // Then
            XCTAssertEqual(mapped.code, prototype.code,
                           "Velocity code \(velocityCode) should map to MAX code \(prototype.code.rawValue)")
        }
    }

    func test_map_everyKnownCode_preservesVelocityCodeAndMessage() {
        for (velocityCode, _) in Self.expectedMappings {
            // Given
            let error = VelocityAdsError(code: velocityCode, message: Self.testMessage)

            // When
            let mapped = VelocityAdsErrorMapper.map(error)

            // Then
            XCTAssertEqual(mapped.mediatedNetworkErrorCode, velocityCode,
                           "Velocity code \(velocityCode) must pass through as mediatedNetworkErrorCode")
            XCTAssertEqual(mapped.mediatedNetworkErrorMessage, Self.testMessage,
                           "Velocity message must pass through as mediatedNetworkErrorMessage")
        }
    }

    func test_map_unknownCode_fallsBackToUnspecified() {
        // Given — a code no VelocityAdsErrorCode constant defines
        let unknownCode = 99_999
        let error = VelocityAdsError(code: unknownCode, message: Self.testMessage)

        // When
        let mapped = VelocityAdsErrorMapper.map(error)

        // Then
        XCTAssertEqual(mapped.code, MAAdapterError.unspecified.code)
        XCTAssertEqual(mapped.mediatedNetworkErrorCode, unknownCode)
        XCTAssertEqual(mapped.mediatedNetworkErrorMessage, Self.testMessage)
    }
}
