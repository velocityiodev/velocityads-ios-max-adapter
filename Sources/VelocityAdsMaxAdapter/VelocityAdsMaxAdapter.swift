import AppLovinSDK
import Foundation
import UIKit
import VelocityAdsSDK

// MARK: - VelocityAdsMaxAdapter

/// AppLovin MAX custom-network adapter for the Velocity Ads iOS SDK.
///
/// Register this class in the MAX dashboard under **Manage Networks → Custom SDK Network**
/// with iOS class name `VelocityAdsMaxAdapter`. Set `app_key` in the **Server Side**
/// parameters for the custom network. Per-placement ad unit IDs are supplied through
/// the placement's **App ID / Placement ID** field.
///
/// Supported ad formats: Interstitial, Rewarded, Native, Banner / MREC / Leaderboard.
@objc(VelocityAdsMaxAdapter)
public final class VelocityAdsMaxAdapter: ALMediationAdapter,
                                           MAInterstitialAdapter,
                                           MARewardedAdapter,
                                           MANativeAdAdapter,
                                           MAAdViewAdapter {

    // MARK: - Private state — interstitial

    private var interstitialAd: VelocityInterstitialAd?
    private var interstitialAdDelegate: VelocityInterstitialAdapterDelegate?

    // MARK: - Private state — rewarded

    private var rewardedAd: VelocityRewardedAd?
    private var rewardedAdDelegate: VelocityRewardedAdapterDelegate?

    // MARK: - Private state — native

    private var nativeAd: VelocityNativeAd?
    private var nativeAdDelegate: VelocityNativeAdapterDelegate?

    // MARK: - Private state — banner

    private var bannerAd: VelocityBannerAd?
    private var bannerAdView: VelocityBannerAdView?
    private var bannerAdDelegate: VelocityBannerAdapterDelegate?

    // MARK: - Private state — init

    /// Set to `true` in `destroy()` so any queued async blocks can bail out early.
    ///
    /// Thread-safety: AppLovin MAX guarantees that all adapter lifecycle methods
    /// (`initialize`, `destroy`, `loadInterstitialAd`, etc.) are called from the
    /// main thread. `isDestroyed` is written in `destroy()` and read inside
    /// main-thread blocks — both happen on the main thread (serial), so no
    /// additional synchronisation is required.
    private var isDestroyed = false

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
        // Privacy must be forwarded before the SDK is initialised.
        forwardPrivacySettings(from: parameters)

        // Fast path — SDK already up.
        if VelocityAds.isInitialized() {
            completionHandler(.initializedSuccess, nil)
            return
        }

        guard let appKey = parameters.serverParameters["app_key"] as? String,
              !appKey.isEmpty else {
            completionHandler(.initializedFailure,
                              "Velocity Ads: missing or empty 'app_key' in server parameters")
            return
        }

        // initSDK must be called on the main thread because VelocityAdsInitDelegate
        // is a @MainActor protocol. The bridge is created inside the block so its
        // @MainActor initialiser runs on the correct actor.
        runOnMainNow { [weak self] in
            guard let self else {
                // Adapter was released before the block ran. MAX no longer holds
                // a reference to this adapter, so calling completionHandler would
                // deliver a result to an already-orphaned context — signal failure
                // so MAX can clean up the pending init on its side.
                completionHandler(.initializedFailure,
                                  "Velocity Ads adapter was released before initialization completed")
                return
            }
            guard !self.isDestroyed else {
                // destroy() was called before this block ran. Signal failure so
                // MAX does not wait indefinitely for a completion that will never
                // arrive via the SDK delegate path.
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
        // Strong self capture is deliberate: it keeps the adapter alive until the
        // teardown has actually run should destroy() ever arrive off-main. On the
        // documented MAX main-thread path the block executes inline, so behavior
        // is unchanged; off-main, confining every mutation to the main actor
        // avoids racing the main-actor-confined readers in the load/show paths.
        //
        // The in-flight init bridge is intentionally NOT touched here: it is
        // coalescer-scoped (see `activeInitBridge`) and must stay alive so parked
        // handlers on other adapter instances still receive the init outcome.
        // Delivery to this destroyed instance is prevented by the `isDestroyed`
        // guards inside the parked handlers themselves.
        runOnMainNow {
            self.isDestroyed = true

            self.interstitialAd?.destroy()
            self.interstitialAd = nil
            self.interstitialAdDelegate = nil

            self.rewardedAd?.destroy()
            self.rewardedAd = nil
            self.rewardedAdDelegate = nil

            self.bannerAd?.destroy()
            self.bannerAd = nil
            self.bannerAdView = nil
            self.bannerAdDelegate = nil

            self.tearDownNativeAd()
        }
    }

    // MARK: - MAInterstitialAdapter

    public func loadInterstitialAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MAInterstitialAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToLoadInterstitialAdWithError(MAAdapterError.invalidLoadState)
                return
            }

            let adUnitId = parameters.thirdPartyAdPlacementIdentifier
            guard !adUnitId.isEmpty else {
                delegate.didFailToLoadInterstitialAdWithError(MAAdapterError.invalidConfiguration)
                return
            }

            self.ensureInitialized(with: parameters) { [weak self] initialized in
                guard let self, !self.isDestroyed else {
                    delegate.didFailToLoadInterstitialAdWithError(MAAdapterError.invalidLoadState)
                    return
                }
                guard initialized else {
                    delegate.didFailToLoadInterstitialAdWithError(MAAdapterError.notInitialized)
                    return
                }

                self.interstitialAd?.destroy()
                self.interstitialAd = nil

                let adDelegate = VelocityInterstitialAdapterDelegate()
                adDelegate.maxDelegate = delegate
                adDelegate.onDismissed = { [weak self] in
                    self?.interstitialAd?.destroy()
                    self?.interstitialAd = nil
                    self?.interstitialAdDelegate = nil
                }

                let request = VelocityInterstitialAdRequest.Builder(adUnitId: adUnitId).build()
                let ad = VelocityInterstitialAd(request)

                self.interstitialAd = ad
                self.interstitialAdDelegate = adDelegate

                ad.load(delegate: adDelegate)
            }
        }
    }

    public func showInterstitialAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MAInterstitialAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToDisplayInterstitialAdWithError(MAAdapterError.invalidLoadState)
                return
            }
            guard let ad = self.interstitialAd, ad.isReady else {
                delegate.didFailToDisplayInterstitialAdWithError(MAAdapterError.adNotReady)
                return
            }

            // Refresh the delegate pointer so display-phase events reach the correct
            // MAInterstitialAdapterDelegate instance, then show.
            //
            // parameters.presentingViewController is deliberately not forwarded:
            // the SDK's only seam (VelocityAds.setPresenterProvider) is a global,
            // set-once override with hard semantics — while set, a nil return means
            // "no presenter" with no auto-discovery fallback, and clearing it would
            // clobber a provider installed by a cross-platform wrapper (Flutter/RN).
            // The SDK's own topmost-VC resolution handles presentation instead.
            self.interstitialAdDelegate?.maxDelegate = delegate
            ad.show()
        }
    }

    // MARK: - MARewardedAdapter

    public func loadRewardedAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MARewardedAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToLoadRewardedAdWithError(MAAdapterError.invalidLoadState)
                return
            }

            let adUnitId = parameters.thirdPartyAdPlacementIdentifier
            guard !adUnitId.isEmpty else {
                delegate.didFailToLoadRewardedAdWithError(MAAdapterError.invalidConfiguration)
                return
            }

            self.ensureInitialized(with: parameters) { [weak self] initialized in
                guard let self, !self.isDestroyed else {
                    delegate.didFailToLoadRewardedAdWithError(MAAdapterError.invalidLoadState)
                    return
                }
                guard initialized else {
                    delegate.didFailToLoadRewardedAdWithError(MAAdapterError.notInitialized)
                    return
                }

                self.rewardedAd?.destroy()
                self.rewardedAd = nil

                let adDelegate = VelocityRewardedAdapterDelegate()
                adDelegate.maxDelegate = delegate
                adDelegate.onDismissed = { [weak self] in
                    self?.rewardedAd?.destroy()
                    self?.rewardedAd = nil
                    self?.rewardedAdDelegate = nil
                }

                let request = VelocityRewardedAdRequest.Builder(adUnitId: adUnitId).build()
                let ad = VelocityRewardedAd(request)

                self.rewardedAd = ad
                self.rewardedAdDelegate = adDelegate

                ad.load(delegate: adDelegate)
            }
        }
    }

    public func showRewardedAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MARewardedAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToDisplayRewardedAdWithError(MAAdapterError.invalidLoadState)
                return
            }
            guard let ad = self.rewardedAd, ad.isReady else {
                delegate.didFailToDisplayRewardedAdWithError(MAAdapterError.adNotReady)
                return
            }

            // Refresh the delegate pointer so display-phase events reach the correct
            // MARewardedAdapterDelegate instance, then show.
            //
            // parameters.presentingViewController is deliberately not forwarded —
            // see the rationale in showInterstitialAd(for:andNotify:).
            self.rewardedAdDelegate?.maxDelegate = delegate
            ad.show()
        }
    }

    // MARK: - MANativeAdAdapter

    public func loadNativeAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MANativeAdAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToLoadNativeAdWithError(MAAdapterError.invalidLoadState)
                return
            }

            let adUnitId = parameters.thirdPartyAdPlacementIdentifier
            guard !adUnitId.isEmpty else {
                delegate.didFailToLoadNativeAdWithError(MAAdapterError.invalidConfiguration)
                return
            }

            self.ensureInitialized(with: parameters) { [weak self] initialized in
                guard let self, !self.isDestroyed else {
                    delegate.didFailToLoadNativeAdWithError(MAAdapterError.invalidLoadState)
                    return
                }
                guard initialized else {
                    delegate.didFailToLoadNativeAdWithError(MAAdapterError.notInitialized)
                    return
                }

                self.tearDownNativeAd()

                let adDelegate = VelocityNativeAdapterDelegate()
                adDelegate.maxDelegate = delegate

                let request = VelocityNativeAdRequest.Builder(adUnitId: adUnitId).build()
                let ad = VelocityNativeAd(request)

                self.nativeAd = ad
                self.nativeAdDelegate = adDelegate

                ad.load(delegate: adDelegate)
            }
        }
    }

    // MARK: - MAAdViewAdapter

    public func loadAdViewAd(
        for parameters: MAAdapterResponseParameters,
        adFormat: MAAdFormat,
        andNotify delegate: MAAdViewAdapterDelegate
    ) {
        runOnMainNow { [weak self] in
            guard let self, !self.isDestroyed else {
                delegate.didFailToLoadAdViewAdWithError(MAAdapterError.invalidLoadState)
                return
            }

            let adUnitId = parameters.thirdPartyAdPlacementIdentifier
            guard !adUnitId.isEmpty else {
                delegate.didFailToLoadAdViewAdWithError(MAAdapterError.invalidConfiguration)
                return
            }

            self.ensureInitialized(with: parameters) { [weak self] initialized in
                guard let self, !self.isDestroyed else {
                    delegate.didFailToLoadAdViewAdWithError(MAAdapterError.invalidLoadState)
                    return
                }
                guard initialized else {
                    delegate.didFailToLoadAdViewAdWithError(MAAdapterError.notInitialized)
                    return
                }

                self.bannerAd?.destroy()
                self.bannerAd = nil
                self.bannerAdView = nil
                self.bannerAdDelegate = nil

                let size = VelocityAdsMaxAdapter.resolveBannerSize(
                    serverParameters: parameters.serverParameters,
                    localExtraParameters: parameters.localExtraParameters,
                    adFormat: adFormat,
                    fallbackWidth: self.fallbackBannerWidth()
                )

                let adView = VelocityBannerAdView()
                self.bannerAdView = adView

                let adDelegate = VelocityBannerAdapterDelegate(maxDelegate: delegate, adView: adView)
                self.bannerAdDelegate = adDelegate

                let request = VelocityBannerAdRequest.Builder(adUnitId: adUnitId, adSize: size).build()
                let ad = VelocityBannerAd(request)
                self.bannerAd = ad

                ad.load(bannerView: adView, delegate: adDelegate)
            }
        }
    }

    // MARK: - Main-thread helpers

    /// Width (pt) used for an adaptive banner when MAX supplies no explicit width.
    ///
    /// Prefers the foreground-active window scene's key window — `connectedScenes`
    /// is an unordered `Set`, so taking an arbitrary scene can pick a background
    /// or external-display scene on multi-scene apps, and the key-window width
    /// (not the screen width) is what matches the available container width in
    /// iPad Split View. Falls back through scene screen width to `UIScreen.main`.
    @MainActor
    private func fallbackBannerWidth() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }
            ?? scenes.first
        guard let scene else {
            return UIScreen.main.bounds.width
        }
        if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            return window.bounds.width
        }
        return scene.screen.bounds.width
    }

    /// Executes `block` on the main actor — inline when already on the main
    /// thread, otherwise deferred via `DispatchQueue.main.async`.
    ///
    /// AppLovin MAX documents that all adapter entry points are invoked on the
    /// main thread, so the inline path is the norm. The async fallback exists so
    /// an off-main call degrades to deferred execution instead of trapping in
    /// `MainActor.assumeIsolated`.
    private func runOnMainNow(_ block: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated(block)
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated(block)
            }
        }
    }

    // MARK: - Native teardown

    /// Tears down the current native ad: marks the `MANativeAd` wrapper as
    /// destroyed first so `prepare(forInteractionClickableViews:)` returns
    /// `false` if MAX re-invokes it on the now-dead ad, then destroys the
    /// Velocity ad and releases both references. Shared by `destroy()` and the
    /// re-load path in `loadNativeAd` so the two cannot drift.
    @MainActor
    private func tearDownNativeAd() {
        nativeAdDelegate?.currentMaxNativeAd?.isAdDestroyed = true
        nativeAd?.destroy()
        nativeAd = nil
        nativeAdDelegate = nil
    }

}
