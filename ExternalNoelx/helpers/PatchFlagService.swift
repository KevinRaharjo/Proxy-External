import Foundation
import os.lock

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Models
// ═══════════════════════════════════════════════════════════════════════

struct PatchFlag: Codable, Equatable {
    let name: String
    let target: String
    let label: String?
    let note: String?
    let updatedAt: Date?

    var key: String { "\(name)@\(target)" }
    var hasLabel: Bool { !(label ?? "").isEmpty }
    var hasNote: Bool { !(note ?? "").isEmpty }
}

struct PatchReportItem: Codable {
    let name: String
    let target: String
}

struct KnownPatch: Codable, Equatable {
    let name: String
    let target: String

    var key: String { "\(name)@\(target)" }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Thread-safe snapshots
// ═══════════════════════════════════════════════════════════════════════

private final class FlagSnapshot: @unchecked Sendable {
    private var lock = os_unfair_lock_s()
    private var storage: [String: PatchFlag] = [:]

    func replace(_ new: [String: PatchFlag]) {
        os_unfair_lock_lock(&lock)
        storage = new
        os_unfair_lock_unlock(&lock)
    }

    func get(_ key: String) -> PatchFlag? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return storage[key]
    }

    func clear() {
        os_unfair_lock_lock(&lock)
        storage.removeAll()
        os_unfair_lock_unlock(&lock)
    }

    func all() -> [PatchFlag] {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return Array(storage.values)
    }
}

private final class KnownSnapshot: @unchecked Sendable {
    private var lock = os_unfair_lock_s()
    private var storage: Set<String> = []

    func replace(_ new: Set<String>) {
        os_unfair_lock_lock(&lock)
        storage = new
        os_unfair_lock_unlock(&lock)
    }

    func contains(_ key: String) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return storage.contains(key)
    }

    func clear() {
        os_unfair_lock_lock(&lock)
        storage.removeAll()
        os_unfair_lock_unlock(&lock)
    }

    func count() -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return storage.count
    }
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Service
// ═══════════════════════════════════════════════════════════════════════

actor PatchFlagService {
    static let shared = PatchFlagService()

    nonisolated let snapshot = FlagSnapshot()
    nonisolated let knownSnapshot = KnownSnapshot()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var lastFlagFetch: Date?
    private var lastKnownFetch: Date?
    private var inFlightFlagFetch: Task<[PatchFlag], Error>?
    private var inFlightKnownFetch: Task<[KnownPatch], Error>?

    private let cacheTTL: TimeInterval = 5 * 60  // 5 menit

    private init() {
        self.baseURL = URL(string: "https://api.proxynixx.my.id/")!

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Fetch Flags (untuk badge di card)
    // ═══════════════════════════════════════════════════════════════════

    @discardableResult
    func fetchFlags(force: Bool = false) async throws -> [PatchFlag] {
        if !force,
           let last = lastFlagFetch,
           Date().timeIntervalSince(last) < cacheTTL {
            return snapshot.all()
        }

        if let existing = inFlightFlagFetch {
            return try await existing.value
        }

        let task = Task<[PatchFlag], Error> { [weak self] in
            guard let self else { return [] }
            return try await self.performFetchFlags()
        }
        inFlightFlagFetch = task
        defer { inFlightFlagFetch = nil }

        return try await task.value
    }

    private func performFetchFlags() async throws -> [PatchFlag] {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/patches/flags"))
        request.httpMethod = "GET"
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            log("patchflag: fetchFlags failed status=\(status)")
            throw APIClientError.serverError(status)
        }

        struct Envelope: Decodable {
            let success: Bool
            let flags: [DTO]
        }
        struct DTO: Decodable {
            let name: String
            let target: String
            let label: String?
            let note: String?
            let updatedAt: Date?
        }

        let envelope = try decoder.decode(Envelope.self, from: data)
        guard envelope.success else { throw APIClientError.decodingFailed }

        let flags = envelope.flags.map {
            PatchFlag(
                name: $0.name,
                target: $0.target,
                label: $0.label,
                note: $0.note,
                updatedAt: $0.updatedAt
            )
        }

        var dict: [String: PatchFlag] = [:]
        for flag in flags { dict[flag.key] = flag }
        snapshot.replace(dict)
        lastFlagFetch = Date()
        log("patchflag: fetched \(flags.count) flags")
        return flags
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Fetch Known Patches (untuk cek mana yang BELUM di server)
    // ═══════════════════════════════════════════════════════════════════

    @discardableResult
    func fetchKnownPatches(force: Bool = false) async throws -> [KnownPatch] {
        if !force,
           let last = lastKnownFetch,
           Date().timeIntervalSince(last) < cacheTTL {
            return []  // snapshot sudah terisi
        }

        if let existing = inFlightKnownFetch {
            return try await existing.value
        }

        let task = Task<[KnownPatch], Error> { [weak self] in
            guard let self else { return [] }
            return try await self.performFetchKnown()
        }
        inFlightKnownFetch = task
        defer { inFlightKnownFetch = nil }

        return try await task.value
    }

    private func performFetchKnown() async throws -> [KnownPatch] {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/patches/known"))
        request.httpMethod = "GET"
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            log("patchflag: fetchKnown failed status=\(status)")
            throw APIClientError.serverError(status)
        }

        struct Envelope: Decodable {
            let success: Bool
            let patches: [DTO]
        }
        struct DTO: Decodable {
            let name: String
            let target: String
        }

        let envelope = try decoder.decode(Envelope.self, from: data)
        guard envelope.success else { throw APIClientError.decodingFailed }

        let patches = envelope.patches.map {
            KnownPatch(name: $0.name, target: $0.target)
        }

        let set = Set(patches.map { $0.key })
        knownSnapshot.replace(set)
        lastKnownFetch = Date()
        log("patchflag: known patches = \(patches.count)")
        return patches
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Report (hanya patch yang BELUM ada di server)
    // ═══════════════════════════════════════════════════════════════════

    /// Report daftar patch. Hanya kirim patch yang belum ada di server.
    /// Kalau semua sudah ada → skip total (return 0).
    @discardableResult
    func report(
        _ patches: [PatchReportItem],
        deviceID: String
    ) async throws -> Int {
        guard !patches.isEmpty else { return 0 }

        // Filter: hanya patch yang belum ada di server
        let toReport = patches.filter {
            !knownSnapshot.contains("\($0.name)@\($0.target)")
        }

        if toReport.isEmpty {
            log("patchflag: all \(patches.count) patches already known, skip report")
            return 0
        }

        log("patchflag: reporting \(toReport.count)/\(patches.count) new patches")

        struct Body: Encodable {
            let patches: [PatchReportItem]
            let device_id: String
        }
        struct Envelope: Decodable {
            let success: Bool
            let reported: Int
            let skipped: Int?
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/patches/report"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try encoder.encode(Body(patches: toReport, device_id: deviceID))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            log("patchflag: report failed status=\(status)")
            throw APIClientError.serverError(status)
        }

        let envelope = try decoder.decode(Envelope.self, from: data)
        guard envelope.success else { throw APIClientError.decodingFailed }

        // Update known snapshot biar next report tidak kirim ulang
        var updated = Set<String>()
        // Ambil snapshot lama dulu
        // (tidak ada accessor, tapi kita bisa replace total)
        // Cukup tambah yang baru ke snapshot via fetch ulang nanti

        log("patchflag: reported \(envelope.reported), server skipped \(envelope.skipped ?? 0)")

        // Refresh known cache
        lastKnownFetch = nil
        _ = try? await fetchKnownPatches(force: true)

        return envelope.reported
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Cache
    // ═══════════════════════════════════════════════════════════════════

    func invalidateCache() {
        snapshot.clear()
        knownSnapshot.clear()
        lastFlagFetch = nil
        lastKnownFetch = nil
    }
}
