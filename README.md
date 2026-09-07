# VelocityAdsMaxAdapter for iOS

AppLovin MAX custom-network adapter that wraps the **Velocity Ads iOS SDK** (`VelocityAdsSDK`) and plugs it into the MAX mediation waterfall.

## Supported ad formats

| Format | Supported |
|---|---|
| Interstitial | ✓ |
| Rewarded | ✓ |
| Banner / MREC / Leaderboard | ✓ |

## Requirements

| Dependency | Minimum version |
|---|---|
| iOS | 13.0 |
| Swift | 5.9 |
| AppLovin MAX SDK | 13.0.0 |
| VelocityAdsSDK | 0.10.0 |

## Installation

### CocoaPods

Add both the adapter and its dependencies to your `Podfile`:

```ruby
pod 'AppLovinSDK',           '>= 13.0.0', '< 14.0.0'
pod 'VelocityAdsSDK',        '~> 0.10.0'
pod 'VelocityAdsMaxAdapter', '0.10.0.0'
```

Then run:

```bash
pod install
```

### Swift Package Manager

SPM requires 3-segment `major.minor.patch` versions, but adapter versions have 4 segments (`A.B.C.D`).
Tags are therefore **encoded** as integers: each segment is zero-padded to 2 digits and concatenated.

| Adapter version | Encoded SPM tag |
|---|---|
| `0.10.0.0` | `100000.0.0` |
| `0.10.0.1` | `100001.0.0` |
| `1.0.0.0`  | `1000000.0.0` |

Formula: `A` `BB` `CC` `DD` (each segment 2 digits, leading zeros on the whole number stripped) → `N.0.0`.

1. In Xcode, go to **File → Add Package Dependencies…**
2. Enter the adapter repository URL:

   ```
   https://github.com/velocityiodev/velocityads-ios-max-adapter
   ```

3. Set the Dependency Rule to **Exact Version** and enter the encoded tag from the [Releases](https://github.com/velocityiodev/velocityads-ios-max-adapter/releases) page (e.g. `100000.0.0` for adapter `0.10.0.0`).
4. Add `VelocityAdsMaxAdapter` to your app target.

The adapter declares its own SPM dependencies on `AppLovinSDK` and `VelocityAdsSDK`, so they are pulled in automatically.

## MAX dashboard setup

1. Log in to the [AppLovin MAX dashboard](https://dash.applovin.com).
2. Navigate to **MAX → Mediation → Manage → Networks**.
3. Click **Click here to add a Custom Network**.
4. Fill in the form:

   | Field | Value |
   |---|---|
   | Network Type | SDK |
   | iOS Adapter Class Name | `VelocityAdsMaxAdapter` |
   | Name | Velocity Ads (or any label) |

5. Save the network.
6. Open the **Ad Units** for your app and add a waterfall line for **Velocity Ads**.
7. In the line's settings, set the **App ID** field to your Velocity Ads app key.
   MAX delivers this value to the adapter as `serverParameters["app_id"]`.
   Use **one Velocity app key per application process** — configuring different App ID values across placements in the same app is unsupported.
8. Set the **Placement ID** field to the Velocity Ads ad unit ID for that placement.
9. Activate the line and publish.

## Privacy

The adapter forwards the device's AppLovin privacy state to the Velocity SDK **before** SDK initialisation and on every ad load. It reads directly from `ALPrivacySettings` — the authoritative iOS source that the publisher (or their CMP) sets — rather than from per-request MAX parameters:

| AppLovin privacy source | Velocity SDK call |
|---|---|
| `ALPrivacySettings.hasUserConsent()` (forwarded only when `isUserConsentSet` is `true`) | `VelocityAds.setConsent(_:)` — `true` = granted (GDPR) |
| `ALPrivacySettings.isDoNotSell()` (forwarded only when `isDoNotSellSet` is `true`) | `VelocityAds.setDoNotSell(_:)` — `true` = opt-out (CCPA) |

A signal that has not been set is not forwarded, and the Velocity SDK retains its previous value. Forwarding on every load means mid-session consent changes propagate on the next request.

## How it works

```
AppLovin MAX SDK
      │
      ▼
VelocityAdsMaxAdapter          (ALMediationAdapter + MAInterstitialAdapter
      │                          + MARewardedAdapter + MAAdViewAdapter)
      │
      ├── VelocityInterstitialAdapterDelegate   (VelocityInterstitialAdDelegate → MAX)
      ├── VelocityRewardedAdapterDelegate       (VelocityRewardedAdDelegate → MAX)
      ├── VelocityBannerAdapterDelegate         (VelocityBannerAdDelegate → MAX)
      └── VelocityAdsErrorMapper                (VelocityAdsError → MAAdapterError)
```

### Lifecycle

**Interstitial / Rewarded**

1. MAX calls `loadInterstitialAd` / `loadRewardedAd` → adapter creates `VelocityInterstitialAd` / `VelocityRewardedAd`, calls `.load(delegate:)`.
2. On success, the delegate bridge calls `didLoadInterstitialAd()` / `didLoadRewardedAd()`.
3. MAX calls `showInterstitialAd` / `showRewardedAd` → adapter checks `isReady`, then calls `.show()` on the main thread.
4. On dismiss, the adapter releases the ad reference.

**Banner / MREC / Leaderboard**

1. MAX calls `loadAdViewAd(for:adFormat:andNotify:)` → adapter resolves size via `resolveBannerSize(...)`: adaptive sizing is gated on the `adaptive_banner` server parameter (boolean), using the `adaptive_banner_width` extra param when present or falling back to the screen width; otherwise the size comes from `adFormat`. It then creates a `VelocityBannerAdView` and `VelocityBannerAd` and calls `.load(bannerView:delegate:)`.
2. On success, the Velocity SDK calls `onAdLoaded(ad:)` on the delegate bridge, which forwards to MAX's `didLoadAd(forAdView:)` with the banner view.
3. MAX places the returned view into its ad container; impression and click callbacks flow through the delegate bridge.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
