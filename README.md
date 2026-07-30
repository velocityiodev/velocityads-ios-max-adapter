# VelocityAdsMaxAdapter for iOS

AppLovin MAX custom-network adapter that wraps the **Velocity Ads iOS SDK** (`VelocityAdsSDK`) and plugs it into the MAX mediation waterfall.

## Supported ad formats

| Format | Supported |
|---|---|
| Interstitial | ✓ |
| Rewarded | ✓ |
| Native | ✓ |
| Banner / MREC | — |

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
pod 'AppLovinSDK',           '>= 13.0.0'
pod 'VelocityAdsSDK',        '0.10.0'
pod 'VelocityAdsMaxAdapter', '0.10.0.0'
```

Then run:

```bash
pod install
```

### Swift Package Manager

1. In Xcode, go to **File → Add Package Dependencies…**
2. Enter the adapter repository URL:

   ```
   https://github.com/velocityiodev/velocityads-ios-max-adapter
   ```

3. Select **Up to Next Major Version** from `0.10.0`.
4. Add `VelocityAdsMaxAdapter` to your app target.

The adapter declares its own SPM dependencies on `AppLovinSDK` and `VelocityAdsSDK`, so they are pulled in automatically.

> **Local development**  
> To test against a local copy of the Velocity SDK, replace the `VelocityAdsSDK` dependency in `Package.swift` with:
> ```swift
> .package(path: "../velocityads-ios-sdk-internal")
> ```

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
7. In the line's settings, under **Server Side Parameters**, add:

   | Key | Value |
   |---|---|
   | `app_key` | Your Velocity Ads app key |

8. Set the **App ID / Placement ID** field to the Velocity Ads ad unit ID for that placement.
9. Activate the line and publish.

## Privacy

The adapter forwards consent and opt-out signals from MAX to the Velocity SDK **before** SDK initialisation:

| MAX parameter | Velocity SDK call |
|---|---|
| `hasUserConsent` (GDPR) | `VelocityAds.setConsent(_:)` — `true` = granted |
| `isDoNotSell` (CCPA) | `VelocityAds.setDoNotSell(_:)` — `true` = opt-out |

Both flags are only forwarded when explicitly set by the publisher; `nil` values (unset) are ignored.

## How it works

```
AppLovin MAX SDK
      │
      ▼
VelocityAdsMaxAdapter          (ALMediationAdapter + MAInterstitialAdapter
      │                          + MARewardedAdapter + MANativeAdAdapter)
      │
      ├── VelocityInterstitialAdapterDelegate   (VelocityInterstitialAdDelegate → MAX)
      ├── VelocityRewardedAdapterDelegate       (VelocityRewardedAdDelegate → MAX)
      ├── VelocityNativeAdapterDelegate         (VelocityNativeAdDelegate → MAX)
      ├── VelocityMaxNativeAd                   (MANativeAd subclass)
      └── VelocityAdsErrorMapper                (VelocityAdsError → MAAdapterError)
```

### Lifecycle

**Interstitial / Rewarded**

1. MAX calls `loadInterstitialAd` / `loadRewardedAd` → adapter creates `VelocityInterstitialAd` / `VelocityRewardedAd`, calls `.load(delegate:)`.
2. On success, the delegate bridge calls `didLoadInterstitialAd()` / `didLoadRewardedAd()`.
3. MAX calls `showInterstitialAd` / `showRewardedAd` → adapter checks `isReady`, then calls `.show()` on the main thread.
4. On dismiss, the adapter releases the ad reference.

**Native**

1. MAX calls `loadNativeAd` → adapter creates `VelocityNativeAd`, calls `.load(delegate:)`.
2. On success, the delegate bridge builds a `VelocityMaxNativeAd` (an `MANativeAd` subclass) from the `NativeAd` data.
3. When MAX renders the native template, it calls `prepare(forInteractionClickableViews:withContainer:)` on `VelocityMaxNativeAd`, which forwards to `VelocityNativeAd.registerViewForInteraction`.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
