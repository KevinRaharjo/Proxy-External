import Foundation

enum ExploitSupportPolicy {

    // MARK: - Fallback ranges (dipakai kalau server belum response)

    static let fallbackVerifiedIOS17Range = "17.0–17.7.x"
    static let fallbackVerifiedIOS18Range = "18.0–18.7.1"
    static let fallbackVerifiedIOS26Range = "26.0–26.6.2"
    static let fallbackVerifiedIOS27Range = "27.0–27.9"

    // MARK: - Display ranges (server-first, fallback kalau server kosong)

    static var verifiedIOS17Range: String {
        serverRange(for: 17) ?? fallbackVerifiedIOS17Range
    }
    static var verifiedIOS18Range: String {
        serverRange(for: 18) ?? fallbackVerifiedIOS18Range
    }
    static var verifiedIOS26Range: String {
        serverRange(for: 26) ?? fallbackVerifiedIOS26Range
    }
    static var verifiedIOS27Range: String {
        serverRange(for: 27) ?? fallbackVerifiedIOS27Range
    }

    private static func serverRange(for major: Int) -> String? {
        guard let v = SupportedVersionsStore.versions.first(where: {
            $0.major == major && ($0.status == "verified" || $0.status == "experimental")
        }) else {
            return nil
        }
        return v.range
    }

    // MARK: - Local kernel exploit support

    /// Cek apakah iOS versi ini punya kernel exploit yang verified.
    /// iOS 17-18 → opa334
    /// iOS 26    → opa334 + BadKernel fallback
    /// iOS 27    → BadKernel
    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        switch major {
        case 17:
            // iOS 17.0 – 17.7.x
            return minor <= 7

        case 18:
            // iOS 18.0 – 18.7.1
            return minor < 7 || (minor == 7 && patch <= 1)

        case 26:
            // iOS 26.0 – 26.6.2 (verified)
            // iOS 26.7+ → experimental (server decide)
            return true  // Let server decide via SupportedVersionsStore

        case 27:
            // iOS 27 → BadKernel
            return true  // Let server decide

        default:
            return false
        }
    }

    // MARK: - Master check (server-first)

    /// Cek support dengan urutan:
    /// 1. Local kernel exploit (paling cepat, gak butuh network)
    /// 2. Server status (kalau ada di store)
    /// 3. Fallback hardcoded (kalau server belum response)
    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        // 1. Local check — kalau iya, langsung return true
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return true
        }

        // 2. Server check — kalau ada rule, pake itu
        if let status = SupportedVersionsStore.status(major: major, minor: minor, patch: patch) {
            return status == "verified" || status == "experimental"
        }

        // 3. Fallback hardcoded
        return fallbackIsSupported(major: major, minor: minor, patch: patch, build: build)
    }

    /// Cek support pake server response (async, lebih akurat)
    /// Panggil ini SEBELUM cek `isSupported` biar server data udah ke-load.
    static func isSupportedAsync(
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) async -> Bool {
        // Pastiin server data udah ke-load
        await SupportedVersionsService.shared.ensureLoaded()

        // Sekarang cek pake server data
        if let status = SupportedVersionsStore.status(major: major, minor: minor, patch: patch) {
            return status == "verified" || status == "experimental"
        }

        // Fallback ke local check
        return isSupported(major: major, minor: minor, patch: patch, build: build)
    }

    // MARK: - Fallback

    private static func fallbackIsSupported(
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) -> Bool {
        // iOS 26.0 – 26.6.2 (verified range)
        if major == 26 {
            guard minor >= 0, patch >= 0 else { return false }
            if minor < 6 { return true }
            if minor == 6 && patch <= 2 { return true }
            return false
        }

        // iOS 27.0 beta builds (verified list)
        if major == 27, minor == 0, patch == 0 {
            return iOS27BetaNumber(for: build) != nil
        }

        return false
    }

    // MARK: - iOS 27 builds

    /// Verified iOS 27 beta builds. Tambahin build baru di sini kalau ada beta baru.
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
