import os.log

/// Unified logging for the adapter. Only warnings are emitted — conditions that have no
/// AppLovin MAX counterpart and would otherwise be invisible to the publisher.
enum AdapterLog {

    private static let log = OSLog(subsystem: "io.velocityads.max", category: "VelocityAdsMaxAdapter")

    static func warn(_ message: String) {
        os_log("%{public}@", log: log, type: .error, message)
    }
}
