import Foundation
import CryptoKit
import Darwin

// Local integrity checks for the app bundle and patch files.
// Complements the server-side validation (Batch 2).
//
// What this checks:
// 1. The app executable has not been modified since install.
// 2. The main Info.plist has not been tampered with.
// 3. Every .3105 patch file hash matches its first-launch snapshot.
// 4. Suspicious hooking / jailbreak frameworks are not loaded.
//
// What this does NOT do:
// - Prevent a determined attacker with reverse-engineering skill.
//   Server-side validation (Batch 2) is required for that.
// - Detect re-signing by eSign / AltStore. The app is expected to be
//   re-signed, so code-signature checks are skipped.

enum IntegrityResult: Equatable {
    case ok
    case tamperedExecutable
    case tamperedInfoPlist
    case tamperedPatch(String)       // patch filename
    case jailedDevice
    case hooked
    case unknown
}

final class IntegrityChecker {

    static let shared = IntegrityChecker()

    // Keychain keys (private to this app).
    private enum Keys {
        static let appExecutableHash = "extNixx.integrity.appExecHash"
        static let infoPlistHash    = "extNixx.integrity.infoPlistHash"
        static let patchHashes      = "extNixx.integrity.patchHashes"
    }

    private let keychainService = "com.apple.mobile.MobileHouseArrest.integrity"

    // MARK: - Public API

    func runLocalChecks() -> IntegrityResult {
        // 1. Jailbreak / hook detection
        if let hookResult = detectHooking() {
            return hookResult
        }

        // 2. Executable integrity
        if let execResult = verifyExecutable() {
            return execResult
        }

        // 3. Info.plist integrity
        if let plistResult = verifyInfoPlist() {
            return plistResult
        }

        // 4. Patch file integrity
        if let patchResult = verifyPatchFiles() {
            return patchResult
        }

        return .ok
    }

    func snapshotOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: "extNixx.integrity.initialized") else {
            return
        }

        if let execHash = computeExecutableHash() {
            keychainSet(key: Keys.appExecutableHash, value: execHash)
        }
        if let plistHash = computeInfoPlistHash() {
            keychainSet(key: Keys.infoPlistHash, value: plistHash)
        }
        let patchHashes = computeAllPatchHashes()
        if let data = try? JSONEncoder().encode(patchHashes) {
            keychainSet(key: Keys.patchHashes, value: data)
        }

        UserDefaults.standard.set(true, forKey: "extNixx.integrity.initialized")
        log("[integrity] snapshot created on first launch")
    }

    // MARK: - Executable hash

    private func computeExecutableHash() -> Data? {
        guard let execPath = Bundle.main.executablePath else { return nil }
        return sha256File(at: execPath)
    }

    private func verifyExecutable() -> IntegrityResult? {
        guard let currentHash = computeExecutableHash(),
              let storedHash = keychainGetData(key: Keys.appExecutableHash) else {
            return nil
        }
        if currentHash != storedHash {
            log("[integrity] ❌ executable hash mismatch")
            return .tamperedExecutable
        }
        return nil
    }

    // MARK: - Info.plist hash

    private func computeInfoPlistHash() -> Data? {
        let path = Bundle.main.bundlePath + "/Info.plist"
        return sha256File(at: path)
    }

    private func verifyInfoPlist() -> IntegrityResult? {
        guard let currentHash = computeInfoPlistHash(),
              let storedHash = keychainGetData(key: Keys.infoPlistHash) else {
            return nil
        }
        if currentHash != storedHash {
            log("[integrity] ❌ Info.plist hash mismatch")
            return .tamperedInfoPlist
        }
        return nil
    }

    // MARK: - Patch files hash

    private func computeAllPatchHashes() -> [String: Data] {
        var result: [String: Data] = [:]
        guard let root = try? PatchProjectLibrary.packageRootURL() else { return result }

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return result }

        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "3105" else { continue }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values?.isRegularFile == true, values?.isSymbolicLink != true else { continue }
            if let hash = sha256File(at: url.path) {
                let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")
                result[relativePath] = hash
            }
        }
        return result
    }

    private func verifyPatchFiles() -> IntegrityResult? {
        guard let storedData = keychainGetData(key: Keys.patchHashes),
              let stored = try? JSONDecoder().decode([String: Data].self, from: storedData) else {
            return nil
        }

        let current = computeAllPatchHashes()

        for (relativePath, storedHash) in stored {
            guard let currentHash = current[relativePath] else {
                log("[integrity] ❌ patch file missing: \(relativePath)")
                return .tamperedPatch(relativePath)
            }
            if currentHash != storedHash {
                log("[integrity] ❌ patch hash mismatch: \(relativePath)")
                return .tamperedPatch(relativePath)
            }
        }

        for relativePath in current.keys where stored[relativePath] == nil {
            log("[integrity] ❌ unauthorised patch added: \(relativePath)")
            return .tamperedPatch(relativePath)
        }

        return nil
    }

    // MARK: - Hook / jailbreak detection
    //
    // IMPORTANT: We do NOT call _dyld_image_count / _dyld_get_image_name here.
    // Those symbols live in <mach-o/dyld.h> and are not exposed to Swift without
    // an explicit shim, and the previous build failed with:
    //     "cannot find '_dyld_image_count' in scope"
    //     "cannot find '_dyld_get_image_name' in scope"
    // Instead we detect hooking using paths and system probes that do not
    // require the dyld image list.

    private func detectHooking() -> IntegrityResult? {
        let fm = FileManager.default

        // 1. Common jailbreak / hooking paths
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Applications/TrollStore.app",
            "/Library/MobileSubstrate",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/lib/libsubstrate.dylib",
            "/usr/lib/libsubstitute.dylib",
            "/usr/lib/libhooker.dylib",
            "/usr/sbin/frida-server",
            "/var/jb",
            "/var/jb/usr/sbin/frida-server",
            "/var/lib/dpkg/status",
            "/bin/bash",
            "/bin/ssh",
            "/private/var/lib/dpkg/status"
        ]
        for path in suspiciousPaths {
            if fm.fileExists(atPath: path) {
                log("[integrity] ❌ jailbreak path detected: \(path)")
                return .jailedDevice
            }
        }

        // 2. Common hooking dylibs via absolute path probe (existence check
        //    is enough for the standard jailbreak layouts).
        let suspiciousDylibs = [
            "/usr/lib/libsubstrate.dylib",
            "/usr/lib/libsubstitute.dylib",
            "/usr/lib/libhooker.dylib",
            "/usr/lib/ellekit/libellekit.dylib",
            "/var/jb/usr/lib/libsubstrate.dylib",
            "/var/jb/usr/lib/libsubstitute.dylib",
            "/var/jb/usr/lib/libhooker.dylib",
            "/var/jb/usr/lib/ellekit/libellekit.dylib",
            "/usr/lib/TweakInject.dylib",
            "/var/jb/usr/lib/TweakInject.dylib"
        ]
        for path in suspiciousDylibs {
            if fm.fileExists(atPath: path) {
                log("[integrity] ❌ suspicious dylib on disk: \(path)")
                return .hooked
            }
        }

        // 3. Writable system paths (jailbreak tell-tale)
        let testPaths = ["/etc/hosts", "/private/etc/hosts"]
        for path in testPaths {
            if fm.isWritableFile(atPath: path) {
                log("[integrity] ❌ writable system path: \(path)")
                return .jailedDevice
            }
        }

        // 4. Ptrace / debugger attached
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        if result == 0 {
            let debugged = (info.kp_proc.p_flag & P_TRACED) != 0
            if debugged {
                log("[integrity] ❌ debugger attached")
                return .hooked
            }
        }

        return nil
    }

    // MARK: - Crypto helpers

    private func sha256File(at path: String) -> Data? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            do {
                guard let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty else {
                    break
                }
                hasher.update(data: chunk)
            } catch {
                return nil
            }
        }
        return Data(hasher.finalize())
    }

    // MARK: - Keychain helpers

    private func keychainSet(key: String, value: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            attributes.forEach { newItem[$0.key] = $0.value }
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private func keychainGetData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Reset (for debugging / new IPA install)

    func resetSnapshot() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "extNixx.integrity.initialized")
        log("[integrity] snapshot reset")
    }
}
