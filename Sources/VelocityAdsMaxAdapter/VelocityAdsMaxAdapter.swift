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
            guard let self else { return }
            let bridge = VelocityAdsInitBridge { status, message in
                self.pendingInitDelegate = nil
                completionHandler(status, message)
            }
            self.pendingInitDelegate = bridge
            VelocityAds.initSDK(request, delegate: bridge)
        }
    }

    public override func destroy() {
        // Release the init bridge first so any in-flight SDK initialisation
        // no longer delivers its completion callback to a destroyed adapter.
        pendingInitDelegate = nil

        interstitialAd?.destroy()
        interstitialAd = nil
        interstitialAdDelegate = nil

        rewardedAd?.destroy()
        rewardedAd = nil
        rewardedAdDelegate = nil

        nativeAd?.destroy()
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
            delegate.didFailToLoadInterstitialAd(withError:
                MAAdapterError(code: MAAdapterError.invalidConfiguration.code,
                               errorString: "Velocity Ads: empty ad unit ID"))
            return
        }

        interstitialAd?.destroy()
        interstitialAd = nil

        let adDelegate = VelocityInterstitialAdapterDelegate()
        adDelegate.maxDelegate = delegate
        adDelegate.onDismissed = { [weak self] in
            self?.interstitialAd = nil
            self?.interstitialAdDelegate = nil
        }

        let request = VelocityInterstitialAdRequest.Builder(adUnitId: adUnitId).build()
        let ad = VelocityInterstitialAd(request)

        interstitialAd = ad
        interstitialAdDelegate = adDelegate

        ad.load(delegate: adDelegate)
    }

    public func showInterstitialAd(
        for parameters: MAAdapterShownAdParameters,
        andNotify delegate: MAInterstitialAdapterDelegate
    ) {
        guard let ad = interstitialAd, ad.isReady else {
            delegate.didFailToDisplayInterstitialAd(withError: .adNotReady)
            return
        }

        // Refresh the delegate pointer so display-phase events reach the correct
        // MAInterstitialAdapterDelegate instance.
        interstitialAdDelegate?.maxDelegate = delegate

        // MAX guarantees showInterstitialAd is called on the main thread.
        // show() is @MainActor; dispatch synchronously to avoid a TOCTOU window.
        DispatchQueue.main.async {
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
            delegate.didFailToLoadRewardedAd(withError:
                MAAdapterError(code: MAAdapterError.invalidConfiguration.code,
                               errorString: "Velocity Ads: empty ad unit ID"))
            return
        }

        rewardedAd?.destroy()
        rewardedAd = nil

        let adDelegate = VelocityRewardedAdapterDelegate()
        adDelegate.maxDelegate = delegate
        adDelegate.onDismissed = { [weak self] in
            self?.rewardedAd = nil
            self?.rewardedAdDelegate = nil
        }

        let request = VelocityRewardedAdRequest.Builder(adUnitId: adUnitId).build()
        let ad = VelocityRewardedAd(request)

        rewardedAd = ad
        rewardedAdDelegate = adDelegate

        ad.load(delegate: adDelegate)
    }

    public func showRewardedAd(
        for parameters: MAAdapterShownAdParameters,
        andNotify delegate: MARewardedAdapterDelegate
    ) {
        guard let ad = rewardedAd, ad.isReady else {
            delegate.didFailToDisplayRewardedAd(withError: .adNotReady)
            return
        }

        // Refresh the delegate pointer so display-phase events reach the correct
        // MARewardedAdapterDelegate instance.
        rewardedAdDelegate?.maxDelegate = delegate

        // MAX guarantees showRewardedAd is called on the main thread.
        // show() is @MainActor; dispatch synchronously to avoid a TOCTOU window.
        DispatchQueue.main.async {
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
            delegate.didFailToLoadNativeAd(withError:
                MAAdapterError(code: MAAdapterError.invalidConfiguration.code,
                               errorString: "Velocity Ads: empty ad unit ID"))
            return
        }

        nativeAd?.destroy()
        nativeAd = nil

        let adDelegate = VelocityNativeAdapterDelegate()
        adDelegate.maxDelegate = delegate

        let request = VelocityNativeAdRequest.Builder(adUnitId: adUnitId).build()
        let ad = VelocityNativeAd(request)

        nativeAd = ad
        nativeAdDelegate = adDelegate

        ad.load(delegate: adDelegate)
    }

    // MARK: - Privacy helpers

    private func forwardPrivacySettings(from parameters: MAAdapterInitializationParameters) {
        if let consent = parameters.hasUserConsent {
            VelocityAds.setConsent(consent.boolValue)
        }
        if let doNotSell = parameters.isDoNotSell {
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
