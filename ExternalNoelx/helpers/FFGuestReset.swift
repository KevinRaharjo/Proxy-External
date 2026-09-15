import Foundation
import UIKit
import Security

enum FFGuestReset {
    /// Free Fire bundle IDs
    static let ffBundleIDs = [
        "com.garena.game.kgth",  // FF Normal
        "com.garena.game.kgid"   // FF Max
    ]

    /// Reset all FF guest data on this device.
    /// After reset, FF will create a fresh guest account on next launch.
    /// Works best for soft bans (7 days, 30 days).
    static func resetAllGuests() throws -> ResetReport {
        var report = ResetReport()
        for bundleID in ffBundleIDs {
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
                         userInfo: [NSLocalizedDescriptionKey: "FF container not found"])
        }

        let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
        let fm = FileManager.default
        var deletedCount = 0

        // ═══════════════════════════════════════════════
        // 1. Delete device_id / guest account files
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
            "Library/Preferences/com.garena.device.plist"
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
        // 2. Delete Garena Preferences
        // ═══════════════════════════════════════════════
        let prefsDir = containerURL.appendingPathComponent("Library/Preferences")
        if let files = try? fm.contentsOfDirectory(at: prefsDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "plist" {
                let name = file.lastPathComponent.lowercased()
                if name.contains("garena") || name.contains("kgth") ||
                   name.contains("kgid") || name.contains("ff.") {
                    try? fm.removeItem(at: file)
                    deletedCount += 1
                    log("FFGuestReset: deleted prefs \(file.lastPathComponent)")
                }
            }
        }

        // ═══════════════════════════════════════════════
        // 3. Delete Cache related to device/guest
        // ═══════════════════════════════════════════════
        let cachesDirs = [
            "Library/Caches",
            "Library/Caches/com.garena.game.kgth",
            "Library/Caches/com.garena.game.kgid"
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
        // 4. Delete Keychain Garena
        // ═══════════════════════════════════════════════
        let keychainServices = [
            "com.garena.game.kgth",
            "com.garena.game.kgid",
            "com.garena.ff",
            "com.garena.device"
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
        let normal = ContainerStore.resolveAppContainerPath(bundleID: "com.garena.game.kgth") != nil
        let max = ContainerStore.resolveAppContainerPath(bundleID: "com.garena.game.kgid") != nil
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
                let short = bundleID == "com.garena.game.kgth" ? "FF Normal" : "FF Max"
                lines.append("✓ \(short): \(count) files deleted")
            }
            for (bundleID, error) in errors {
                lines.append("✗ \(bundleID): \(error)")
            }
            return lines.joined(separator: "\n")
        }
    }
}
