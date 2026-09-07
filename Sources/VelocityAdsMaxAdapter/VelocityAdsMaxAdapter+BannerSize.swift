import AppLovinSDK
import CoreGraphics
import Foundation
import VelocityAdsSDK

// MARK: - Banner size resolution

extension VelocityAdsMaxAdapter {

    /// Resolves the Velocity banner size for a MAX ad-view request.
    ///
    /// Follows AppLovin's adaptive-banner contract: adaptive sizing is gated on the
    /// `adaptive_banner` **server parameter** (a boolean), not on the presence of an
    /// explicit width. When adaptive is enabled the width comes from the
    /// `adaptive_banner_width` local-extra parameter if provided (and positive),
    /// otherwise it falls back to `fallbackWidth` (typically the screen / container
    /// width in points). When adaptive is disabled the size is chosen from `adFormat`:
    /// MREC → `.mrec`, leaderboard → `.leaderboard`, everything else → `.banner`.
    ///
    /// This function is pure (no UIKit / global state access) so it can be unit-tested
    /// in isolation; the caller supplies `fallbackWidth`.
    ///
    /// - Parameters:
    ///   - serverParameters: The MAX server-side parameters dictionary.
    ///   - localExtraParameters: The MAX local-extra parameters dictionary.
    ///   - adFormat: The requested MAX ad format.
    ///   - fallbackWidth: Width (pt) to use for an adaptive banner when no explicit
    ///     positive width is supplied via `adaptive_banner_width`.
    /// - Returns: The resolved `VelocityBannerAdSize`.
    static func resolveBannerSize(
        serverParameters: [AnyHashable: Any],
        localExtraParameters: [AnyHashable: Any],
        adFormat: MAAdFormat,
        fallbackWidth: CGFloat
    ) -> VelocityBannerAdSize {
        if boolValue(serverParameters["adaptive_banner"]) {
            if let widthNumber = localExtraParameters["adaptive_banner_width"] as? NSNumber {
                let requestedWidth = CGFloat(widthNumber.doubleValue)
                if requestedWidth > 0 {
                    return .adaptiveBanner(width: requestedWidth)
                }
            }
            return .adaptiveBanner(width: fallbackWidth)
        }

        if adFormat == MAAdFormat.mrec {
            return .mrec
        }
        if adFormat == MAAdFormat.leader {
            return .leaderboard
        }
        return .banner
    }

    /// Interprets a MAX parameter value as a boolean. MAX may deliver booleans as
    /// `NSNumber` or as a string (`"true"` / `"1"`); anything else is treated as
    /// `false` so a missing or malformed value degrades safely.
    private static func boolValue(_ value: Any?) -> Bool {
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            switch string.lowercased() {
            case "true", "1", "yes":
                return true
            default:
                return false
            }
        }
        return false
    }
}
