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

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Thread-safe snapshot
// ═══════════════════════════════════════════════════════════════════════

/// Snapshot thread-safe untuk baca cache dari View tanpa `await`.
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

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Service
// ═══════════════════════════════════════════════════════════════════════

actor PatchFlagService {
    static let shared = PatchFlagService()

    /// Snapshot thread-safe — bisa dibaca dari View tanpa `await`.
    nonisolated let snapshot = FlagSnapshot()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var lastFetch: Date?
    private var inFlightFetch: Task<[PatchFlag], Error>?

    private let cacheTTL: TimeInterval = 5 * 60        // 5 menit
    private let reportDebounce: TimeInterval = 10 * 60  // 10 menit
    private var lastReportAt: Date?

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
    // MARK: - Fetch Flags
    // ═══════════════════════════════════════════════════════════════════

    /// Fetch daftar flag dari server. Cache 5 menit.
    /// `force = true` → bypass cache.
    @discardableResult
    func fetchFlags(force: Bool = false) async throws -> [PatchFlag] {
        if !force,
           let last = lastFetch,
           Date().timeIntervalSince(last) < cacheTTL {
            return snapshot.all()
        }

        if let existing = inFlightFetch {
            return try await existing.value
        }

        let task = Task<[PatchFlag], Error> { [weak self] in
            guard let self else { return [] }
            return try await self.performFetch()
        }
        inFlightFetch = task
        defer { inFlightFetch = nil }

        return try await task.value
    }

    private func performFetch() async throws -> [PatchFlag] {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/patches/flags"))
        request.httpMethod = "GET"
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            log("patchflag: fetch failed status=\(status)")
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
        lastFetch = Date()
        log("patchflag: fetched \(flags.count) flags")
        return flags
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Report Patches
    // ═══════════════════════════════════════════════════════════════════

    /// Report daftar patch dari app ke server. Debounced 10 menit.
    @discardableResult
    func report(_ patches: [PatchReportItem], force: Bool = false) async throws -> Int {
        if !force,
           let last = lastReportAt,
           Date().timeIntervalSince(last) < reportDebounce {
            log("patchflag: report skipped (debounced)")
            return 0
        }
        guard !patches.isEmpty else { return 0 }

        struct Body: Encodable { let patches: [PatchReportItem] }
        struct Envelope: Decodable { let success: Bool; let reported: Int }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/patches/report"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try encoder.encode(Body(patches: patches))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            log("patchflag: report failed status=\(status)")
            throw APIClientError.serverError(status)
        }

        let envelope = try decoder.decode(Envelope.self, from: data)
        guard envelope.success else { throw APIClientError.decodingFailed }

        lastReportAt = Date()
        log("patchflag: reported \(envelope.reported) patches")
        return envelope.reported
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Cache
    // ═══════════════════════════════════════════════════════════════════

    func invalidateCache() {
        snapshot.clear()
        lastFetch = nil
    }
}
