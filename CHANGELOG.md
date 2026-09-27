# Changelog

## [0.11.0.0] - Unreleased

### Breaking Changes

* **Minimum iOS version raised from 13.0 to 15.0**, matching Velocity Ads iOS SDK 0.11.0. Apps with a lower deployment target must raise it to 15.0 before upgrading; CocoaPods and Swift Package Manager will not resolve the adapter otherwise.

### Changed

* Wraps Velocity Ads iOS SDK 0.11.0.

## [0.10.1.0] - 2026-09-16

### Changed

* Wraps Velocity Ads iOS SDK 0.10.1.

## [0.10.0.0] - 2026-09-07

### Added

* Initial release of the Velocity Ads AppLovin MAX custom-network adapter for iOS.
* Wraps Velocity Ads iOS SDK 0.10.0.
* Supports AppLovin MAX SDK 13.x.
* Requires iOS 13.0 or later.
* Supported ad formats: Interstitial, Rewarded, and Banner / MREC / Leaderboard.
* Reads the Velocity app key from the **App ID** field of the MAX dashboard ad-unit entry.
* Forwards GDPR user consent and CCPA Do Not Sell signals from AppLovin to the Velocity SDK.
