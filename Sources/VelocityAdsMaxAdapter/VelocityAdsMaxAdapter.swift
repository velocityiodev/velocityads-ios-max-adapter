import AppLovinSDK
import Foundation
import VelocityAdsSDK

// MARK: - VelocityAdsMaxAdapter

/// AppLovin MAX custom-network adapter for the Velocity Ads iOS SDK.
///
/// Register this class in the MAX dashboard under **Manage Networks → Custom SDK Network**
/// with iOS class name `VelocityAdsMaxAdapter`. Set the Velocity app key in the **App ID**
/// field of every ad unit's Velocity Ads waterfall entry — MAX delivers it as
/// `serverParameters["app_id"]`. Per-placement Velocity ad unit IDs are supplied through
/// the **Placement ID** field.
///
/// Supported ad formats: Interstitial, Rewarded, Banner / MREC / Leaderboard.
@objc(VelocityAdsMaxAdapter)
public final class VelocityAdsMaxAdapter: ALMediationAdapter {

    // MARK: - State — interstitial

    var interstitialAd: VelocityInterstitialAd?
    var interstitialAdDelegate: VelocityInterstitialAdapterDelegate?

    // MARK: - State — rewarded

    var rewardedAd: VelocityRewardedAd?
    var rewardedAdDelegate: VelocityRewardedAdapterDelegate?

    // MARK: - State — banner

    var bannerAd: VelocityBannerAd?
    var bannerAdView: VelocityBannerAdView?
    var bannerAdDelegate: VelocityBannerAdapterDelegate?

    // MARK: - State — lifecycle

    /// Set to `true` in `destroy()` so any queued async blocks can bail out early.
    ///
    /// Thread-safety: AppLovin MAX guarantees that all adapter lifecycle methods
    /// (`initialize`, `destroy`, `loadInterstitialAd`, etc.) are called from the
    /// main thread. `isDestroyed` is written in `destroy()` and read inside
    /// main-thread blocks — both happen on the main thread (serial), so no
    /// additional synchronisation is required.
    var isDestroyed = false

    // MARK: - ALMediationAdapter overrides

    public override var sdkVersion: String {
        VelocityAds.getSdkVersion()
    }

    public override var adapterVersion: String {
        velocityAdsMaxAdapterVersion
    }

    public override func initialize(
        with parameters: MAAdapterInitializationParameters,
        completionHandler: @escaping (MAAdapterInitializationStatus, String?) -> Void
    ) {
        // Identify the mediation environment before SDK init so the very first
        // request and event carry it.
        forwardMediationInfo()
        // Forward privacy before SDK init so consent is set from the first request.
        forwardPrivacySettings()

        // Fast path — SDK already up.
        if VelocityAds.isInitialized() {
            completionHandler(.initializedSuccess, nil)
            return
        }

        // The App ID field is optional in the MAX dashboard's Custom Network settings, so
        // app_id may not be present at network-level initialization time. Report
        // initializedUnknown — the adapter is ready but the app key arrives via the
        // per-placement App ID field at load time; ensureInitialized() performs the
        // real SDK init lazily on the first load.
        guard let appKey = (parameters.serverParameters["app_id"] as? String)?.nilIfEmpty else {
            completionHandler(.initializedUnknown, nil)
            return
        }

        // initSDK must be called on the main thread because VelocityAdsInitDelegate
        // is a @MainActor protocol. The bridge is created inside the block so its
        // @MainActor initialiser runs on the correct actor.
        runOnMainNow { [weak self] in
            guard let self else {
                completionHandler(.initializedFailure,
                                  "Velocity Ads adapter was released before initialization completed")
                return
            }
            guard !self.isDestroyed else {
                completionHandler(.initializedFailure,
                                  "Velocity Ads adapter was destroyed before initialization completed")
                return
            }
            // Re-check: another adapter instance may have finished SDK init in the
            // meantime (concurrent initialize() calls from MAX).
            if VelocityAds.isInitialized() {
                completionHandler(.initializedSuccess, nil)
                return
            }
            let won = VelocityAdsMaxAdapter.initCoalescer.claim { [weak self] outcome in
                // A destroyed adapter still owes MAX exactly one completion —
                // degrade to failure rather than leaving MAX to hit its own
                // init timeout waiting for a callback that never comes.
                if self?.isDestroyed == true {
                    completionHandler(.initializedFailure,
                                      "Velocity Ads adapter was destroyed before initialization completed")
                    return
                }
                completionHandler(outcome.status, outcome.message)
            }
            if won {
                self.startClaimedInit(appKey: appKey)
            }
        }
    }

    public override func destroy() {
        // The in-flight init bridge is intentionally NOT touched here: it is
        // coalescer-scoped (see `activeInitBridge`) and must stay alive so parked
        // handlers on other adapter instances still receive the init outcome.
        // Delivery to this destroyed instance is prevented by the `isDestroyed`
        // guards inside the parked handlers themselves.
        isDestroyed = true

        interstitialAd?.destroy()
        interstitialAd = nil
        interstitialAdDelegate = nil

        rewardedAd?.destroy()
        rewardedAd = nil
        rewardedAdDelegate = nil

        bannerAd?.destroy()
        bannerAd = nil
        bannerAdView = nil
        bannerAdDelegate = nil
    }

    // MARK: - Main-thread helper

    /// Executes `block` on the main actor — inline when already on the main
    /// thread, otherwise deferred via `DispatchQueue.main.async`.
    ///
    /// AppLovin MAX documents that all adapter entry points are invoked on the
    /// main thread, so the inline path is the norm. The async fallback exists so
    /// an off-main call degrades to deferred execution instead of trapping in
    /// `MainActor.assumeIsolated`.
    func runOnMainNow(_ block: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(block)
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated(block)
            }
        }
    }
}
