import AppLovinSDK
import VelocityAdsSDK

/// Maps `VelocityAdsError` codes to the closest `MAAdapterError` equivalent.
enum VelocityAdsErrorMapper {

    // MARK: - Public

    static func map(_ error: VelocityAdsError) -> MAAdapterError {
        switch error.code {

        // Network / HTTP layer
        case VelocityAdsErrorCode.invalidURL:
            return make(MAAdapterError.badRequest, message: error.message)
        case VelocityAdsErrorCode.networkError:
            return make(MAAdapterError.noConnection, message: error.message)
        case VelocityAdsErrorCode.jsonParseError:
            return make(MAAdapterError.badRequest, message: error.message)
        case VelocityAdsErrorCode.invalidResponse:
            return make(MAAdapterError.badRequest, message: error.message)
        case VelocityAdsErrorCode.emptyResponseBody:
            return make(MAAdapterError.badRequest, message: error.message)
        case VelocityAdsErrorCode.serverErrorField:
            return make(MAAdapterError.serverError, message: error.message)
        case VelocityAdsErrorCode.httpFailure:
            return make(MAAdapterError.serverError, message: error.message)

        // SDK init / configuration
        case VelocityAdsErrorCode.invalidAppKey:
            return make(MAAdapterError.invalidConfiguration, message: error.message)
        case VelocityAdsErrorCode.sdkNotInitialized:
            return make(MAAdapterError.notInitialized, message: error.message)
        case VelocityAdsErrorCode.sdkInitializationInProgress:
            return make(MAAdapterError.notInitialized, message: error.message)

        // Load lifecycle
        case VelocityAdsErrorCode.loadAlreadyInProgress:
            return make(MAAdapterError.invalidLoadState, message: error.message)
        case VelocityAdsErrorCode.loadServiceUnavailable:
            return make(MAAdapterError.notInitialized, message: error.message)
        case VelocityAdsErrorCode.invalidAdResponse:
            return make(MAAdapterError.badRequest, message: error.message)
        case VelocityAdsErrorCode.noFill:
            return make(MAAdapterError.noFill, message: error.message)
        case VelocityAdsErrorCode.internalError:
            return make(MAAdapterError.internalError, message: error.message)
        case VelocityAdsErrorCode.adAlreadyLoaded:
            return make(MAAdapterError.invalidLoadState, message: error.message)
        case VelocityAdsErrorCode.waterfallLoadFailed:
            return make(MAAdapterError.internalError, message: error.message)
        case VelocityAdsErrorCode.adDestroyed:
            return make(MAAdapterError.invalidLoadState, message: error.message)
        case VelocityAdsErrorCode.invalidAdUnitId:
            return make(MAAdapterError.invalidConfiguration, message: error.message)
        case VelocityAdsErrorCode.adSpent:
            return make(MAAdapterError.adExpiredError, message: error.message)

        default:
            return make(MAAdapterError.unspecified, message: error.message)
        }
    }

    // MARK: - Private

    /// Creates an `MAAdapterError` from a pre-built prototype's code, preserving the
    /// Velocity error message for visibility in MAX logs.
    ///
    /// `MAAdapterError.xxx.code` returns `MAErrorCode` (an ObjC NS_ENUM). `.rawValue` extracts
    /// the underlying `Int` required by `errorWithCode:errorString:`.
    private static func make(_ prototype: MAAdapterError, message: String) -> MAAdapterError {
        MAAdapterError(code: prototype.code.rawValue, errorString: message)
    }
}
