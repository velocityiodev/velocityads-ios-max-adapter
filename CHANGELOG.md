# Changelog

## [0.12.0.0] - Unreleased

### Changed

* Wraps Velocity Ads iOS SDK 0.12.0.
* Supports Apple AdAttributionKit for eligible campaigns. Publishers must add
  `rwn33vua23.adattributionkit` to the `AdNetworkIdentifiers` array in the host
  app's `Info.plist`.

## [0.11.0.0] - 2026-10-04

### Breaking Changes

* Raised minimum iOS deployment target to iOS 15.0.

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
