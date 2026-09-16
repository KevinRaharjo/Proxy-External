import Foundation
import UIKit
import Security

enum FFGuestReset {
    /// Free Fire bundle IDs — covers both Garena and DTS variants.
    static let ffBundleIDs = [
        // FF Normal
        "com.dts.freefireth",         // DTS variant (global/SEA)
        "com.garena.game.kgth",       // Garena variant
        // FF Max
        "com.dts.freefiremax",        // DTS variant
        "com.garena.game.kgid"        // Garena variant
    ]

    /// Bundle IDs that belong to "Normal" FF.
    private static let normalBundles: Set<String> = [
        "com.dts.freefireth",
        "com.garena.game.kgth"
    ]

    /// Bundle IDs that belong to "Max" FF.
    private static let maxBundles: Set<String> = [
        "com.dts.freefiremax",
        "com.garena.game.kgid"
    ]

    /// Reset all FF guest data on this device.
    /// After reset, FF will create a fresh guest account on next launch.
    /// Works best for soft bans (7 days, 30 days).
    static func resetAllGuests() throws -> ResetReport {
        var report = ResetReport()

        for bundleID in ffBundleIDs {
            // Skip bundles that aren't installed
            guard ContainerStore.resolveAppContainerPath(bundleID: bundleID) != nil else {
                log("FFGuestReset: skip \(bundleID) — not installed")
                continue
            }
            do {
                let count = try resetGuest(bundleID: bundleID)
                report.perBundle[bundleID] = count
            } catch {
                report.errors[bundleID] = error.localizedDescription
            }
        }
        return report
    }

    /// Reset guest for a single FF bundle.
    static func resetGuest(bundleID: String) throws -> Int {
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
              ContainerStore.isApplicationContainerPath(containerPath) else {
            throw NSError(domain: "FFGuestReset", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "FF container not found for \(bundleID)"])
        }

        let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
        let fm = FileManager.default
        var deletedCount = 0

        // ═══════════════════════════════════════════════
        // 1. Delete `reset_guest.flag` (guest reset marker)
        //    FF creates this when resetting; if it exists,
        //    FF skips reset. Deleting it forces a new reset.
        // ═══════════════════════════════════════════════
        let resetFlagPath = containerURL.appendingPathComponent("Documents/reset_guest.flag")
        if fm.fileExists(atPath: resetFlagPath.path) {
            try? fm.removeItem(at: resetFlagPath)
            deletedCount += 1
            log("FFGuestReset: deleted Documents/reset_guest.flag")
        }

        // ═══════════════════════════════════════════════
        // 2. Delete device_id / guest account files
        // ═══════════════════════════════════════════════
        let deviceIDFiles = [
            "Documents/device_id.txt",
            "Documents/ff_device_id",
            "Documents/.device_id",
            "Documents/UserInfo.dat",
            "Documents/Account.dat",
            "Documents/guest.dat",
            "Documents/user_account.txt",
            "Documents/DeviceInfo.dat",
            "Library/Caches/device_id.dat",
            "Library/Caches/com.garena.device.plist",
            "Library/Caches/com.dts.device.plist",
            "Library/Preferences/com.garena.device.plist",
            "Library/Preferences/com.dts.device.plist"
        ]

        for relativePath in deviceIDFiles {
            let fileURL = containerURL.appendingPathComponent(relativePath)
            if fm.fileExists(atPath: fileURL.path) {
                try? fm.removeItem(at: fileURL)
                deletedCount += 1
                log("FFGuestReset: deleted \(relativePath)")
            }
        }

        // ═══════════════════════════════════════════════
        // 3. Delete Garena / DTS Preferences
        // ═══════════════════════════════════════════════
        let prefsDir = containerURL.appendingPathComponent("Library/Preferences")
        if let files = try? fm.contentsOfDirectory(at: prefsDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "plist" {
                let name = file.lastPathComponent.lowercased()
                if name.contains("garena") || name.contains("dts") ||
                   name.contains("kgth") || name.contains("kgid") ||
                   name.contains("freefire") || name.contains("ff.") {
                    try? fm.removeItem(at: file)
                    deletedCount += 1
                    log("FFGuestReset: deleted prefs \(file.lastPathComponent)")
                }
            }
        }

        // ═══════════════════════════════════════════════
        // 4. Delete Cache related to device/guest
        // ═══════════════════════════════════════════════
        let cachesDirs = [
            "Library/Caches",
            "Library/Caches/com.garena.game.kgth",
            "Library/Caches/com.garena.game.kgid",
            "Library/Caches/com.dts.freefireth",
            "Library/Caches/com.dts.freefiremax"
        ]

        for cachesDir in cachesDirs {
            let dirURL = containerURL.appendingPathComponent(cachesDir)
            guard fm.fileExists(atPath: dirURL.path) else { continue }
            if let files = try? fm.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil) {
                for file in files {
                    let name = file.lastPathComponent.lowercased()
                    if name.contains("device") || name.contains("guest") ||
                       name.contains("token") || name.contains("session") {
                        try? fm.removeItem(at: file)
                        deletedCount += 1
                        log("FFGuestReset: deleted cache \(name)")
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════
        // 5. Delete Keychain Garena / DTS
        // ═══════════════════════════════════════════════
        let keychainServices = [
            "com.garena.game.kgth",
            "com.garena.game.kgid",
            "com.dts.freefireth",
            "com.dts.freefiremax",
            "com.garena.ff",
            "com.garena.device",
            "com.dts.ff",
            "com.dts.device"
        ]

        for service in keychainServices {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service
            ]
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess {
                deletedCount += 1
                log("FFGuestReset: deleted keychain \(service)")
            }
        }

        log("FFGuestReset: total deleted for \(bundleID) = \(deletedCount)")
        return deletedCount
    }

    /// Check if FF is installed.
    static func isFFInstalled() -> (normal: Bool, max: Bool) {
        var normal = false
        var max = false

        for bundleID in ffBundleIDs {
            let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID)
            log("FFGuestReset: check bundle=\(bundleID) path=\(path ?? "nil")")

            guard path != nil else { continue }
            if normalBundles.contains(bundleID) { normal = true }
            if maxBundles.contains(bundleID) { max = true }
        }

        log("FFGuestReset: isFFInstalled normal=\(normal) max=\(max)")
        return (normal, max)
    }

    struct ResetReport {
        var perBundle: [String: Int] = [:]
        var errors: [String: String] = [:]

        var totalDeleted: Int { perBundle.values.reduce(0, +) }

        var summary: String {
            if perBundle.isEmpty && errors.isEmpty {
                return "No FF installed on this device"
            }
            var lines: [String] = []
            for (bundleID, count) in perBundle {
                let short: String
                if bundleID.contains("freefireth") || bundleID.contains("kgth") {
                    short = "FF Normal"
                } else if bundleID.contains("freefiremax") || bundleID.contains("kgid") {
                    short = "FF Max"
                } else {
                    short = bundleID
                }
                lines.append("✓ \(short): \(count) files deleted")
            }
            for (bundleID, error) in errors {
                lines.append("✗ \(bundleID): \(error)")
            }
            return lines.joined(separator: "\n")
        }
    }
}
