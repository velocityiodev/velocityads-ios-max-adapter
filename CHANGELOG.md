# Changelog

## [Unreleased]

### Changed

* A Velocity load failure caused by unreachable ad media (Velocity SDK error `2013`, `mediaUnreachable`) is now reported to MAX as `noFill` instead of `unspecified`, so the mediation waterfall moves on to the next network rather than treating it as an adapter fault. Requires Velocity Ads iOS SDK 0.11.0 or later to be emitted.

## [0.10.0.0] - 2026-09-07

### Added

* Initial release of the Velocity Ads AppLovin MAX custom-network adapter for iOS.
* Wraps Velocity Ads iOS SDK 0.10.0.
* Supports AppLovin MAX SDK 13.x.
* Requires iOS 13.0 or later.
* Supported ad formats: Interstitial, Rewarded, and Banner / MREC / Leaderboard.
* Reads the Velocity app key from the **App ID** field of the MAX dashboard ad-unit entry.
* Forwards GDPR user consent and CCPA Do Not Sell signals from AppLovin to the Velocity SDK.
