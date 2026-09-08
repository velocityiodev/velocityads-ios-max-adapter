# Changelog

## [Unreleased]

### Changed

* Ad loads whose waterfall entry has no **App ID** now reuse the App ID seen at initialization instead of failing, matching the Android adapter.
* A second, different App ID observed in the same app process is reported once through the unified logging system (`io.velocityads.max`).

## [0.10.0.0] - 2026-09-07

### Added

* Initial release of the Velocity Ads AppLovin MAX custom-network adapter for iOS.
* Wraps Velocity Ads iOS SDK 0.10.0.
* Supports AppLovin MAX SDK 13.x.
* Requires iOS 13.0 or later.
* Supported ad formats: Interstitial, Rewarded, and Banner / MREC / Leaderboard.
* Reads the Velocity app key from the **App ID** field of the MAX dashboard ad-unit entry.
* Forwards GDPR user consent and CCPA Do Not Sell signals from AppLovin to the Velocity SDK.
