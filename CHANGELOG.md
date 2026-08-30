# Changelog

## 0.10.0.0
_2026-08-30_

* Initial release of the Velocity Ads AppLovin MAX custom-network adapter for iOS.
* Wraps Velocity Ads iOS SDK 0.10.0.
* Supports AppLovin MAX SDK 13.x.
* Requires iOS 13.0 or later.
* Supported ad formats:
  * **Interstitial** — full-screen interstitial ads (video, HTML/MRAID, static image).
  * **Rewarded** — full-screen rewarded ads with publisher-configurable reward currency and amount.
  * **Native** — native ads supplying headline, body, call-to-action, icon, and main image assets for custom publisher rendering.
  * **Banner / MREC / Leaderboard** — inline banner ads; adaptive banner width is resolved from the active window to correctly support iPad Split View.
* The Velocity app key is read from the **App ID** field of the MAX dashboard ad-unit entry and delivered via `serverParameters["app_id"]`.
* Lazy SDK initialization: if the app key is absent at MAX network-level `initialize`, the adapter initializes the Velocity SDK on the first load that carries a valid app key. Concurrent init calls are coalesced so only one `initSDK` attempt is in flight at a time.
* GDPR user consent and CCPA Do Not Sell signals are forwarded from MAX to the Velocity SDK at both init time and on every ad load.
