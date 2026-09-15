/// Single source of truth for the adapter version string reported to AppLovin MAX.
///
/// Follows the MAX convention of 4 segments: the wrapped SDK's 3-segment semver
/// plus a trailing adapter-build segment. Each release carries two git tags: the
/// full 4-segment version (e.g. `0.10.1.0`) for CocoaPods — `VelocityAdsMaxAdapter.podspec`
/// derives its `:tag` from `s.version` — and an encoded 3-segment tag for Swift
/// Package Manager, which only accepts semver: each segment zero-padded to two
/// digits and concatenated (`0.10.1.0` → `00100100` → `100100.0.0`). When
/// releasing, bump this constant and the podspec `s.version` together.
internal let velocityAdsMaxAdapterVersion = "0.10.1.0"

/// Mediation name reported to the Velocity SDK via `VelocityAdsMediationBridge`.
/// Owned by this adapter — the SDK accepts any lowercase canonical string.
internal let velocityAdsMediationName = "max"

internal extension String {
    /// Returns `nil` when the string is empty, `self` otherwise.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
