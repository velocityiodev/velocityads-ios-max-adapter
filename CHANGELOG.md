# Changelog

## [Unreleased]

### Changed

* Ad units whose waterfall entry has no **App ID** now load using the App ID configured on any other Velocity entry in the app.

## [0.10.0.0] - 2026-09-07

### Added

* Initial release of the Velocity Ads AppLovin MAX custom-network adapter for iOS.
* Wraps Velocity Ads iOS SDK 0.10.0.
* Supports AppLovin MAX SDK 13.x.
* Requires iOS 13.0 or later.
* Supported ad formats: Interstitial, Rewarded, and Banner / MREC / Leaderboard.
* Reads the Velocity app key from the **App ID** field of the MAX dashboard ad-unit entry.
* Forwards GDPR user consent and CCPA Do Not Sell signals from AppLovin to the Velocity SDK.
