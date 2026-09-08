/// Single source of truth for the adapter version string reported to AppLovin MAX.
///
/// Four segments: the wrapped SDK's 3-segment semver plus a trailing adapter-build
/// segment. `VelocityAdsMaxAdapter.podspec` `s.version` must always match — bump both
/// together when releasing.
internal let velocityAdsMaxAdapterVersion = "0.10.0.0"

/// Mediation name reported to the Velocity SDK.
internal let velocityAdsMediationName = "max"

internal extension String {
    /// Returns `nil` when the string is empty, `self` otherwise.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
