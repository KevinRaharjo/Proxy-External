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

    private static let normalBundles: Set<String> = [
        "com.dts.freefireth",
        "com.garena.game.kgth"
    ]

    private static let maxBundles: Set<String> = [
        "com.dts.freefiremax",
        "com.garena.game.kgid"
    ]

    /// ═══════════════════════════════════════════════════════════════
    /// MARK: - LocalConfig.json Content
    /// ═══════════════════════════════════════════════════════════════
    ///
    /// File ini di-write ke Documents/LocalConfig.json
    /// FF baca → liat resetGuest: true → FF reset guest sendiri
    ///
    /// testCodePatch: true → buat bypass patch verification FF
    /// resetGuest: true → trigger guest reset
    ///
    static let localConfigContent = """
    {"testCodePatch":true,"resetGuest":true}
    """

    /// ═══════════════════════════════════════════════════════════════
    /// MARK: - Main Reset
    /// ═══════════════════════════════════════════════════════════════

    /// Reset all FF guest data on this device.
    /// Setelah reset, FF bakal create fresh guest account next launch.
    static func resetAllGuests() throws -> ResetReport {
        var report = ResetReport()

        for bundleID in ffBundleIDs {
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
    /// Write `{"testCodePatch":true,"resetGuest":true}` to Documents/LocalConfig.json
    static func resetGuest(bundleID: String) throws -> Int {
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
              ContainerStore.isApplicationContainerPath(containerPath) else {
            throw NSError(
                domain: "FFGuestReset",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "FF container not found for \(bundleID)"]
            )
        }

        let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
        let fm = FileManager.default
        var writtenCount = 0

        log("FFGuestReset: container = \(containerPath)")

        // ═══════════════════════════════════════════════════════════════
        // 1. Ensure Documents folder exists
        // ═══════════════════════════════════════════════════════════════
        let documentsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        if !fm.fileExists(atPath: documentsURL.path) {
            try fm.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            log("FFGuestReset: created Documents folder")
        }

        // ═══════════════════════════════════════════════════════════════
        // 2. WRITE LocalConfig.json (overwrite existing)
        // ═══════════════════════════════════════════════════════════════
        let localConfigPath = documentsURL.appendingPathComponent("LocalConfig.json")

        do {
            // Backup dulu kalau ada (buat restore kalau gagal)
            var backupData: Data?
            if fm.fileExists(atPath: localConfigPath.path) {
                backupData = try? Data(contentsOf: localConfigPath)
                log("FFGuestReset: backed up existing LocalConfig.json (\(backupData?.count ?? 0) bytes)")
            }

            // Tulis content baru
            guard let data = localConfigContent.data(using: .utf8) else {
                throw NSError(
                    domain: "FFGuestReset",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encode LocalConfig content"]
                )
            }

            try data.write(to: localConfigPath, options: .atomic)

            // Verify
            guard fm.fileExists(atPath: localConfigPath.path) else {
                throw NSError(
                    domain: "FFGuestReset",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "LocalConfig.json was not written"]
                )
            }

            // Verify content
            let verifyData = try Data(contentsOf: localConfigPath)
            let verifyString = String(data: verifyData, encoding: .utf8) ?? ""
            log("FFGuestReset: ✅ wrote LocalConfig.json: \(verifyString)")

            writtenCount += 1

            // Set file permission biar FF bisa baca
            try? fm.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: localConfigPath.path
            )

        } catch {
            log("FFGuestReset: ❌ failed to write LocalConfig.json — \(error.localizedDescription)")
            throw error
        }

        // ═══════════════════════════════════════════════════════════════
        // 3. Also write reset_guest.flag (marker tambahan)
        // ═══════════════════════════════════════════════════════════════
        let resetFlagPath = documentsURL.appendingPathComponent("reset_guest.flag")
        do {
            try localConfigContent.write(to: resetFlagPath, atomically: true, encoding: .utf8)
            writtenCount += 1
            log("FFGuestReset: ✅ wrote reset_guest.flag")
        } catch {
            log("FFGuestReset: ⚠️ failed to write reset_guest.flag — \(error.localizedDescription)")
            // Non-fatal, tetep lanjut
        }

        // ═══════════════════════════════════════════════════════════════
        // 4. VERIFY — pastikan file ada & content bener
        // ═══════════════════════════════════════════════════════════════
        let finalData = try? Data(contentsOf: localConfigPath)
        let finalString = finalData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let expected = localConfigContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let actual = finalString.trimmingCharacters(in: .whitespacesAndNewlines)

        if actual != expected {
            log("FFGuestReset: ⚠️ content mismatch — expected: \(expected), actual: \(actual)")
        } else {
            log("FFGuestReset: ✅ verification passed")
        }

        log("FFGuestReset: total written for \(bundleID) = \(writtenCount)")
        return writtenCount
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

    /// Cek apakah file LocalConfig.json udah ada content reset
    static func isResetPending(bundleID: String) -> Bool {
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: bundleID) else {
            return false
        }
        let path = URL(fileURLWithPath: containerPath, isDirectory: true)
            .appendingPathComponent("Documents/LocalConfig.json")
        guard let data = try? Data(contentsOf: path),
              let content = String(data: data, encoding: .utf8) else {
            return false
        }
        return content.contains("\"resetGuest\":true")
    }

    // ═══════════════════════════════════════════════════════════════
    // MARK: - Report
    // ═══════════════════════════════════════════════════════════════

    struct ResetReport {
        var perBundle: [String: Int] = [:]
        var errors: [String: String] = [:]

        var totalWritten: Int { perBundle.values.reduce(0, +) }

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
                lines.append("✓ \(short): LocalConfig.json written (\(count) files)")
            }
            for (bundleID, error) in errors {
                lines.append("✗ \(bundleID): \(error)")
            }
            return lines.joined(separator: "\n")
        }
    }
}
