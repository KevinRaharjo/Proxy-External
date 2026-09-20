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
            return minor <= 7

        case 18:
            return minor < 7 || (minor == 7 && patch <= 1)

        case 26:
            // iOS 26+ → let server decide
            return true

        case 27:
            // iOS 27+ → let server decide
            return true

        default:
            return false
        }
    }

    // MARK: - Master check (SYNC — pake data yang udah ada)

    /// Cek support dengan urutan:
    /// 1. Server status (kalau ada di store) ← PRIORITAS UTAMA
    /// 2. iOS 26/27 → return true (server yang decide)
    /// 3. Local kernel exploit (iOS 17-18)
    /// 4. Fallback hardcoded
    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        // ═══ PRIORITAS 1: Server status (kalau udah ke-fetch) ═══
        if let status = SupportedVersionsStore.status(major: major, minor: minor, patch: patch) {
            return status == "verified" || status == "experimental"
        }

        // ═══ PRIORITAS 2: iOS 26 & 27 → let server decide ═══
        // Kalau server belum fetch, anggap supported dulu
        // Biar app lanjut, nanti server yang reject kalau emang gak support
        if major == 26 || major == 27 {
            return true
        }

        // ═══ PRIORITAS 3: Local kernel exploit (iOS 17-18) ═══
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return true
        }

        // ═══ PRIORITAS 4: Fallback hardcoded ═══
        return fallbackIsSupported(major: major, minor: minor, patch: patch, build: build)
    }

    // MARK: - Master check (ASYNC — fetch server dulu)

    /// Cek support pake server response (async, paling akurat).
    /// Panggil ini di launch session biar server data udah ke-load.
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

        // Kalau server gak punya rule buat versi ini, fallback
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
