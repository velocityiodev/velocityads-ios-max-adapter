/// Single source of truth for the adapter version string reported to AppLovin MAX.
///
/// Follows the MAX convention of 4 segments: the wrapped SDK's 3-segment semver
/// plus a trailing adapter-build segment. Git release tags use only the first
/// three segments (e.g. `0.10.0`) so Swift Package Manager can resolve them;
/// `VelocityAdsMaxAdapter.podspec` derives its `:tag` from `s.version` the same
/// way. When releasing, bump this constant and the podspec `s.version` together,
/// then tag with the 3-segment prefix.
internal let velocityAdsMaxAdapterVersion = "0.10.0.0"

internal extension String {
    /// Returns `nil` when the string is empty, `self` otherwise.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
