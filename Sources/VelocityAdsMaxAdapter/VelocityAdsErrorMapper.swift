import AppLovinSDK
import VelocityAdsSDK

/// Maps `VelocityAdsError` codes to the closest `MAAdapterError` equivalent.
enum VelocityAdsErrorMapper {

    // MARK: - Public

    static func map(_ error: VelocityAdsError) -> MAAdapterError {
        switch error.code {

        // Network / HTTP layer
        case VelocityAdsErrorCode.invalidURL:
            return MAAdapterError(code: MAAdapterError.badRequest.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.networkError:
            return MAAdapterError(code: MAAdapterError.noConnection.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.jsonParseError:
            return MAAdapterError(code: MAAdapterError.badRequest.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.invalidResponse:
            return MAAdapterError(code: MAAdapterError.badRequest.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.emptyResponseBody:
            return MAAdapterError(code: MAAdapterError.badRequest.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.serverErrorField:
            return MAAdapterError(code: MAAdapterError.serverError.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.httpFailure:
            return MAAdapterError(code: MAAdapterError.serverError.code,
                                  errorString: error.message)

        // SDK init / configuration
        case VelocityAdsErrorCode.invalidAppKey:
            return MAAdapterError(code: MAAdapterError.invalidConfiguration.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.sdkNotInitialized:
            return MAAdapterError(code: MAAdapterError.notInitialized.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.sdkInitializationInProgress:
            return MAAdapterError(code: MAAdapterError.notInitialized.code,
                                  errorString: error.message)

        // Load lifecycle
        case VelocityAdsErrorCode.loadAlreadyInProgress:
            return MAAdapterError(code: MAAdapterError.invalidLoadState.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.loadServiceUnavailable:
            return MAAdapterError(code: MAAdapterError.notInitialized.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.invalidAdResponse:
            return MAAdapterError(code: MAAdapterError.badRequest.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.noFill:
            return MAAdapterError(code: MAAdapterError.noFill.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.internalError:
            return MAAdapterError(code: MAAdapterError.internalError.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.adAlreadyLoaded:
            return MAAdapterError(code: MAAdapterError.invalidLoadState.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.waterfallLoadFailed:
            return MAAdapterError(code: MAAdapterError.internalError.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.adDestroyed:
            return MAAdapterError(code: MAAdapterError.invalidLoadState.code,
                                  errorString: error.message)
        case VelocityAdsErrorCode.invalidAdUnitId:
            return MAAdapterError(code: MAAdapterError.invalidConfiguration.code,
                                  errorString: error.message)

        default:
            return MAAdapterError(code: MAAdapterError.unspecified.code,
                                  errorString: error.message)
        }
    }
}
