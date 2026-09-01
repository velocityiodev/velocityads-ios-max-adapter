# VelocityAdsMaxAdapter for iOS

AppLovin MAX custom-network adapter that wraps the **Velocity Ads iOS SDK** (`VelocityAdsSDK`) and plugs it into the MAX mediation waterfall.

## Supported ad formats

| Format | Supported |
|---|---|
| Interstitial | ✓ |
| Rewarded | ✓ |
| Native | ✓ |
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

> The adapter pod version follows the MAX 4-segment convention (`0.10.0.0` = SDK semver + adapter build); its git release tag is the 3-segment prefix (`0.10.0`).

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

3. Select **Up to Next Major Version** from `0.10.0` (release tags use 3-segment semver).
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
7. In the line's settings, set the **App ID** field to your Velocity Ads app key.
   MAX delivers this value to the adapter as `serverParameters["app_id"]`.
8. Set the **Placement ID** field to the Velocity Ads ad unit ID for that placement.
9. Activate the line and publish.

## Privacy

The adapter forwards consent and opt-out signals from MAX to the Velocity SDK **before** SDK initialisation:

| MAX parameter | Velocity SDK call |
|---|---|
| `hasUserConsent` (GDPR) | `VelocityAds.setConsent(_:)` — `true` = granted |
| `isDoNotSell` (CCPA) | `VelocityAds.setDoNotSell(_:)` — `true` = opt-out |

Both flags are only forwarded when explicitly set by the publisher; `nil` values (unset) are ignored.

## Mediation environment reporting

At initialisation the adapter reports the mediation environment to the Velocity SDK via `VelocityAdsMediationBridge.setMediationInfo(name:adapterVersion:sdkVersion:)`:

| Field | Value |
|---|---|
| Mediation name | `"max"` |
| Adapter version | This adapter's version (e.g. `0.10.0.0`) |
| Mediation SDK version | The AppLovin SDK version (`ALSdk.version()`) |

The Velocity SDK attaches these values to every ad request (`mobileMetadata`) and every analytics event, so traffic can be sliced by mediation platform, adapter version, and AppLovin SDK version. Forwarding happens once per process — the values never change mid-session.

## How it works

```
AppLovin MAX SDK
      │
      ▼
VelocityAdsMaxAdapter          (ALMediationAdapter + MAInterstitialAdapter
      │                          + MARewardedAdapter + MANativeAdAdapter
      │                          + MAAdViewAdapter)
      │
      ├── VelocityInterstitialAdapterDelegate   (VelocityInterstitialAdDelegate → MAX)
      ├── VelocityRewardedAdapterDelegate       (VelocityRewardedAdDelegate → MAX)
      ├── VelocityNativeAdapterDelegate         (VelocityNativeAdDelegate → MAX)
      ├── VelocityBannerAdapterDelegate         (VelocityBannerAdDelegate → MAX)
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

**Banner / MREC / Leaderboard**

1. MAX calls `loadAdViewAd(for:adFormat:andNotify:)` → adapter resolves size via `resolveBannerSize(...)`: adaptive sizing is gated on the `adaptive_banner` server parameter (boolean), using the `adaptive_banner_width` extra param when present or falling back to the screen width; otherwise the size comes from `adFormat`. It then creates a `VelocityBannerAdView` and `VelocityBannerAd` and calls `.load(bannerView:delegate:)`.
2. On success, `VelocityBannerAdapterDelegate` calls `didLoadAdForAdView(_:)` with the banner view.
3. MAX places the returned view into its ad container; impression and click callbacks flow through the delegate bridge.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

---

## Release process

> **SDK-first requirement**: the `velocityads-ios-sdk` `0.10.0` tag must exist on the public repo and `VelocityAdsSDK 0.10.0` must be on CocoaPods trunk before this adapter can be released. CI and `pod spec lint` will fail until then.

### Prerequisites

Set the following secrets at the **`velocityiodev` org level** (shared automatically with all adapter repos):

| Secret | Purpose |
|---|---|
| `GPG_PRIVATE_KEY` | GPG private key for git tag signing (armored) |
| `GPG_PASSPHRASE` | Passphrase for `GPG_PRIVATE_KEY` (empty string if none) |
| `GPG_TAGGER_NAME` | Display name for signed git tags |
| `GPG_TAGGER_EMAIL` | Email for signed git tags |
| `GPG_SIGNING_KEY_ID` | Full-length GPG key fingerprint for tag signing |
| `COCOAPODS_TRUNK_TOKEN` | CocoaPods trunk session token — keep alive with the `cocoapods-keepalive.yml` workflow |

### Steps

1. On a release branch (`release/<version>`, e.g. `release/0.10.0.0`):
   - Bump `velocityAdsMaxAdapterVersion` in `Sources/VelocityAdsMaxAdapter/AdapterVersion.swift`.
   - Bump `s.version` in `VelocityAdsMaxAdapter.podspec`.
   - Add a `## <version>` entry to `CHANGELOG.md`.
2. Push the branch and open a draft PR for review.
3. **After the Velocity SDK tag and CocoaPods pod are published**, go to **Actions → Publish Adapter** and click **Run workflow**:
   - **Branch**: your release branch.
   - **Version**: the 4-segment version, e.g. `0.10.0.0`.
   - **Dry run**: `true` to validate everything without creating the tag or pushing to trunk; `false` for the real release.
4. If the dry run passes, re-run with **Dry run = false**.
5. Merge the release PR after the workflow succeeds.

The workflow creates a GPG-signed 3-segment git tag (e.g. `0.10.0`), a GitHub Release with CHANGELOG notes and SPM/CocoaPods install snippets, and pushes the podspec to CocoaPods trunk.
