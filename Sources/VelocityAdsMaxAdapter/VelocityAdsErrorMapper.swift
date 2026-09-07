import AppLovinSDK
import VelocityAdsSDK

/// Maps `VelocityAdsError` codes to the closest `MAAdapterError` equivalent.
enum VelocityAdsErrorMapper {

    // MARK: - Public

    static func map(_ error: VelocityAdsError) -> MAAdapterError {
        switch error.code {

        // Network / HTTP layer
        case VelocityAdsErrorCode.invalidURL:
            return make(MAAdapterError.badRequest, from: error)
        case VelocityAdsErrorCode.networkError:
            return make(MAAdapterError.noConnection, from: error)
        case VelocityAdsErrorCode.jsonParseError:
            return make(MAAdapterError.badRequest, from: error)
        case VelocityAdsErrorCode.invalidResponse:
            return make(MAAdapterError.badRequest, from: error)
        case VelocityAdsErrorCode.emptyResponseBody:
            return make(MAAdapterError.badRequest, from: error)
        case VelocityAdsErrorCode.serverErrorField:
            return make(MAAdapterError.serverError, from: error)
        case VelocityAdsErrorCode.httpFailure:
            return make(MAAdapterError.serverError, from: error)

        // SDK init / configuration
        case VelocityAdsErrorCode.invalidAppKey:
            return make(MAAdapterError.invalidConfiguration, from: error)
        case VelocityAdsErrorCode.sdkNotInitialized:
            return make(MAAdapterError.notInitialized, from: error)
        case VelocityAdsErrorCode.sdkInitializationInProgress:
            return make(MAAdapterError.notInitialized, from: error)

        // Load lifecycle
        case VelocityAdsErrorCode.loadAlreadyInProgress:
            return make(MAAdapterError.invalidLoadState, from: error)
        case VelocityAdsErrorCode.loadServiceUnavailable:
            return make(MAAdapterError.notInitialized, from: error)
        case VelocityAdsErrorCode.invalidAdResponse:
            return make(MAAdapterError.badRequest, from: error)
        case VelocityAdsErrorCode.noFill:
            return make(MAAdapterError.noFill, from: error)
        case VelocityAdsErrorCode.internalError:
            return make(MAAdapterError.internalError, from: error)
        case VelocityAdsErrorCode.adAlreadyLoaded:
            return make(MAAdapterError.invalidLoadState, from: error)
        case VelocityAdsErrorCode.waterfallLoadFailed:
            return make(MAAdapterError.internalError, from: error)
        case VelocityAdsErrorCode.adDestroyed:
            return make(MAAdapterError.invalidLoadState, from: error)
        case VelocityAdsErrorCode.invalidAdUnitId:
            return make(MAAdapterError.invalidConfiguration, from: error)
        case VelocityAdsErrorCode.adSpent:
            return make(MAAdapterError.adExpiredError, from: error)

        default:
            return make(MAAdapterError.unspecified, from: error)
        }
    }

    // MARK: - Private

    /// Creates an `MAAdapterError` from a pre-built prototype, passing the full
    /// Velocity error through as the mediated-network error so both the Velocity
    /// code and message stay visible in MAX logs.
    private static func make(_ prototype: MAAdapterError, from error: VelocityAdsError) -> MAAdapterError {
        MAAdapterError(adapterError: prototype,
                       mediatedNetworkErrorCode: error.code,
                       mediatedNetworkErrorMessage: error.message)
    }
}
