import Foundation

enum ExploitSupportPolicy {
    // MARK: - Fallback (kalo server gak reachable)

    static let fallbackVerifiedIOS17Range = "17.0–17.7.x"
    static let fallbackVerifiedIOS18Range = "18.0–18.7.1"
    static let fallbackVerifiedIOS26Range = "26.0–26.6.2"

    // MARK: - Display ranges (buat Settings UI)

    static var verifiedIOS17Range: String {
        serverRange(for: 17) ?? fallbackVerifiedIOS17Range
    }
    static var verifiedIOS18Range: String {
        serverRange(for: 18) ?? fallbackVerifiedIOS18Range
    }
    static var verifiedIOS26Range: String {
        serverRange(for: 26) ?? fallbackVerifiedIOS26Range
    }

    private static func serverRange(for major: Int) -> String? {
        guard let v = SupportedVersionsStore.versions.first(where: {
            $0.major == major && $0.status == "verified"
        }) else {
            return nil
        }
        return v.range
    }

    // MARK: - Support check

    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        return false
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        // 1. iOS 17-18: hardcoded (stable)
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return true
        }

        // 2. iOS 26+: cek server
        if let status = SupportedVersionsStore.status(major: major, minor: minor, patch: patch) {
            return status == "verified" || status == "experimental"
        }

        // 3. Fallback
        return fallbackIsSupported(major: major, minor: minor, patch: patch, build: build)
    }

    private static func fallbackIsSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        if major == 26 {
            guard minor >= 0, patch >= 0 else { return false }
            if minor < 6 { return true }
            if minor == 6 && patch <= 2 { return true }
            return false
        }

        if major == 27, minor == 0, patch == 0 {
            return iOS27BetaNumber(for: build) != nil
        }

        return false
    }

    static let verifiedIOS27Builds: [(beta: Int, publicBeta: Int?, build: String)] = [
        (1, nil, "24A5355q"),
        (2, nil, "24A5370h"),
        (3, 1, "24A5380h"),
        (4, 2, "24A5390f")
    ]

    static func iOS27BetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.beta
    }

    static func iOS27PublicBetaNumber(for build: String) -> Int? {
        verifiedIOS27Builds.first { $0.build == build }?.publicBeta
    }
}
