import AppLovinSDK
import VelocityAdsSDK

// MARK: - VelocityAdsMaxAdapter

/// AppLovin MAX custom-network adapter for the Velocity Ads iOS SDK.
///
/// Register this class in the MAX dashboard under **Manage Networks → Custom SDK Network**
/// with iOS class name `VelocityAdsMaxAdapter`. Set `app_key` in the **Server Side**
/// parameters for the custom network. Per-placement ad unit IDs are supplied through
/// the placement's **App ID / Placement ID** field.
///
/// Supported ad formats: Interstitial, Rewarded, Native.
@objc(VelocityAdsMaxAdapter)
public final class VelocityAdsMaxAdapter: ALMediationAdapter,
                                           MAInterstitialAdapter,
                                           MARewardedAdapter,
                                           MANativeAdAdapter {

    // MARK: - Private state — interstitial

    private var interstitialAd: VelocityInterstitialAd?
    private var interstitialAdDelegate: VelocityInterstitialAdapterDelegate?

    // MARK: - Private state — rewarded

    private var rewardedAd: VelocityRewardedAd?
    private var rewardedAdDelegate: VelocityRewardedAdapterDelegate?

    // MARK: - Private state — native

    private var nativeAd: VelocityNativeAd?
    private var nativeAdDelegate: VelocityNativeAdapterDelegate?

    // MARK: - Private state — init

    /// Held strongly so the delegate is alive for the duration of async SDK initialisation.
    private var pendingInitDelegate: VelocityAdsInitBridge?

    /// Set to `true` in `destroy()` so any queued async blocks can bail out early.
    ///
    /// Thread-safety: AppLovin MAX guarantees that all adapter lifecycle methods
    /// (`initialize`, `destroy`, `loadInterstitialAd`, etc.) are called from the
    /// main thread. `isDestroyed` is written in `destroy()` and read inside a
    /// `DispatchQueue.main.async` block — both happen on the main thread (serial),
    /// so no additional synchronisation is required.
    private var isDestroyed = false

    // MARK: - ALMediationAdapter overrides

    public override var sdkVersion: String {
        VelocityAds.getSdkVersion()
    }

    public override var adapterVersion: String {
        "0.10.0.0"
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

        let request = VelocityAdsInitRequest.Builder(appKey).build()

        // initSDK must be called on the main thread because VelocityAdsInitDelegate
        // is a @MainActor protocol. The bridge is created inside the block so its
        // @MainActor initialiser runs on the correct actor.
        DispatchQueue.main.async { [weak self] in
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
            // Re-check: another adapter instance may have finished SDK init during
            // the dispatch hop (concurrent initialize() calls from MAX).
            if VelocityAds.isInitialized() {
                completionHandler(.initializedSuccess, nil)
                return
            }
            let bridge = VelocityAdsInitBridge { [weak self] status, message in
                self?.pendingInitDelegate = nil
                completionHandler(status, message)
            }
            self.pendingInitDelegate = bridge
            VelocityAds.initSDK(request, delegate: bridge)
        }
    }

    public override func destroy() {
        isDestroyed = true

        // Release the init bridge first so any in-flight SDK initialisation
        // no longer delivers its completion callback to a destroyed adapter.
        pendingInitDelegate = nil

        interstitialAd?.destroy()
        interstitialAd = nil
        interstitialAdDelegate = nil

        rewardedAd?.destroy()
        rewardedAd = nil
        rewardedAdDelegate = nil

        // VelocityNativeAd.destroy() is @MainActor; MAX guarantees destroy() is
        // called on the main thread so assumeIsolated is safe here.
        // Mark the MANativeAd as destroyed first so prepare(forInteractionClickableViews:)
        // returns false if MAX re-invokes it on the now-dead ad.
        MainActor.assumeIsolated {
            nativeAdDelegate?.currentMaxNativeAd?.isAdDestroyed = true
            nativeAd?.destroy()
        }
        nativeAd = nil
        nativeAdDelegate = nil
    }

    // MARK: - MAInterstitialAdapter

    public func loadInterstitialAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MAInterstitialAdapterDelegate
    ) {
        let adUnitId = parameters.thirdPartyAdPlacementIdentifier
        guard !adUnitId.isEmpty else {
            delegate.didFailToLoadInterstitialAdWithError(MAAdapterError.invalidConfiguration)
            return
        }

        interstitialAd?.destroy()
        interstitialAd = nil

        // VelocityInterstitialAdapterDelegate is @MainActor; MAX guarantees load is
        // called on the main thread so assumeIsolated is safe here.
        let adDelegate = MainActor.assumeIsolated {
            let d = VelocityInterstitialAdapterDelegate()
            d.maxDelegate = delegate
            d.onDismissed = { [weak self] in
                self?.interstitialAd = nil
                self?.interstitialAdDelegate = nil
            }
            return d
        }

        let request = VelocityInterstitialAdRequest.Builder(adUnitId: adUnitId).build()
        let ad = VelocityInterstitialAd(request)

        interstitialAd = ad
        interstitialAdDelegate = adDelegate

        ad.load(delegate: adDelegate)
    }

    public func showInterstitialAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MAInterstitialAdapterDelegate
    ) {
        guard let ad = interstitialAd, ad.isReady else {
            delegate.didFailToDisplayInterstitialAdWithError(MAAdapterError.adNotReady)
            return
        }

        // Refresh the delegate pointer so display-phase events reach the correct
        // MAInterstitialAdapterDelegate instance, then show.
        // MAX guarantees showInterstitialAd is called on the main thread.
        MainActor.assumeIsolated {
            interstitialAdDelegate?.maxDelegate = delegate
            ad.show()
        }
    }

    // MARK: - MARewardedAdapter

    public func loadRewardedAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MARewardedAdapterDelegate
    ) {
        let adUnitId = parameters.thirdPartyAdPlacementIdentifier
        guard !adUnitId.isEmpty else {
            delegate.didFailToLoadRewardedAdWithError(MAAdapterError.invalidConfiguration)
            return
        }

        rewardedAd?.destroy()
        rewardedAd = nil

        // VelocityRewardedAdapterDelegate is @MainActor; MAX guarantees load is
        // called on the main thread so assumeIsolated is safe here.
        let adDelegate = MainActor.assumeIsolated {
            let d = VelocityRewardedAdapterDelegate()
            d.maxDelegate = delegate
            d.onDismissed = { [weak self] in
                self?.rewardedAd = nil
                self?.rewardedAdDelegate = nil
            }
            return d
        }

        let request = VelocityRewardedAdRequest.Builder(adUnitId: adUnitId).build()
        let ad = VelocityRewardedAd(request)

        rewardedAd = ad
        rewardedAdDelegate = adDelegate

        ad.load(delegate: adDelegate)
    }

    public func showRewardedAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MARewardedAdapterDelegate
    ) {
        guard let ad = rewardedAd, ad.isReady else {
            delegate.didFailToDisplayRewardedAdWithError(MAAdapterError.adNotReady)
            return
        }

        // Refresh the delegate pointer so display-phase events reach the correct
        // MARewardedAdapterDelegate instance, then show.
        // MAX guarantees showRewardedAd is called on the main thread.
        MainActor.assumeIsolated {
            rewardedAdDelegate?.maxDelegate = delegate
            ad.show()
        }
    }

    // MARK: - MANativeAdAdapter

    public func loadNativeAd(
        for parameters: MAAdapterResponseParameters,
        andNotify delegate: MANativeAdAdapterDelegate
    ) {
        let adUnitId = parameters.thirdPartyAdPlacementIdentifier
        guard !adUnitId.isEmpty else {
            delegate.didFailToLoadNativeAdWithError(MAAdapterError.invalidConfiguration)
            return
        }

        // VelocityNativeAd.destroy() and VelocityNativeAdapterDelegate are @MainActor;
        // MAX guarantees load is called on the main thread so assumeIsolated is safe.
        let adDelegate = MainActor.assumeIsolated {
            nativeAd?.destroy()
            nativeAd = nil

            let d = VelocityNativeAdapterDelegate()
            d.maxDelegate = delegate
            return d
        }

        let request = VelocityNativeAdRequest.Builder(adUnitId: adUnitId).build()
        let ad = VelocityNativeAd(request)

        nativeAd = ad
        nativeAdDelegate = adDelegate

        ad.load(delegate: adDelegate)
    }

    // MARK: - Privacy helpers

    private func forwardPrivacySettings(from parameters: MAAdapterInitializationParameters) {
        if let consent = parameters.userConsent {
            VelocityAds.setConsent(consent.boolValue)
        }
        if let doNotSell = parameters.doNotSell {
            VelocityAds.setDoNotSell(doNotSell.boolValue)
        }
    }
}

// MARK: - VelocityAdsInitBridge

/// Internal helper that routes `VelocityAdsInitDelegate` callbacks to the MAX
/// completion handler. Kept alive as `pendingInitDelegate` on the adapter.
///
/// Marked `@MainActor` because `VelocityAdsInitDelegate` is a `@MainActor` protocol.
@MainActor
private final class VelocityAdsInitBridge: NSObject, VelocityAdsInitDelegate {

    private let handler: (MAAdapterInitializationStatus, String?) -> Void

    init(handler: @escaping (MAAdapterInitializationStatus, String?) -> Void) {
        self.handler = handler
    }

    func onInitSuccess() {
        handler(.initializedSuccess, nil)
    }

    func onInitFailure(error: VelocityAdsError) {
        handler(.initializedFailure, "[\(error.code)] \(error.message)")
    }
}
