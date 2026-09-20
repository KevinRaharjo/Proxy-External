import Foundation

struct SupportedVersion: Codable, Identifiable {
    let id: Int
    let range: String
    let major: Int
    let minorStart: Int
    let minorEnd: Int
    let patchEnd: Int
    let status: String
    let notes: String?
    let updatedAt: String?
}

struct SupportedVersionsResponse: Codable {
    let success: Bool
    let versions: [SupportedVersion]?
}

/// Thread-safe storage — biar bisa dibaca dari manapun
enum SupportedVersionsStore {
    private static let lock = NSLock()
    private static var _versions: [SupportedVersion] = []

    static var versions: [SupportedVersion] {
        lock.lock()
        defer { lock.unlock() }
        return _versions
    }

    static func replace(_ new: [SupportedVersion]) {
        lock.lock()
        defer { lock.unlock() }
        _versions = new
    }

    static func status(major: Int, minor: Int, patch: Int) -> String? {
        lock.lock()
        defer { lock.unlock() }
        for version in _versions {
            guard version.major == major else { continue }
            if minor >= version.minorStart && minor <= version.minorEnd {
                if minor == version.minorEnd && patch > version.patchEnd {
                    continue
                }
                return version.status
            }
        }
        return nil
    }
}

actor SupportedVersionsService {
    static let shared = SupportedVersionsService()

    private let baseURL = URL(string: "https://api.proxynixx.my.id/")!
    private let session: URLSession
    private let decoder: JSONDecoder

    private var lastFetch: Date?
    private let cacheTTL: TimeInterval = 300
    private var loadTask: Task<[SupportedVersion], Error>?

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    /// Pastiin server data udah ke-load. Kalau belum, fetch sekarang.
    /// Kalau udah, return langsung.
    func ensureLoaded() async {
        // Kalau udah ada data, skip
        if !SupportedVersionsStore.versions.isEmpty {
            return
        }
        // Kalau ada task in-flight, tungguin
        if let task = loadTask {
            _ = try? await task.value
            return
        }
        // Fetch sekarang
        _ = try? await fetch(force: false)
    }

    func fetch(force: Bool = false) async throws -> [SupportedVersion] {
        // Kalau udah ada cache & belum expired
        if !force, let last = lastFetch, Date().timeIntervalSince(last) < cacheTTL {
            return SupportedVersionsStore.versions
        }

        // Kalau ada task in-flight, join aja
        if let existing = loadTask {
            return try await existing.value
        }

        let task = Task<[SupportedVersion], Error> { [weak self] in
            guard let self else { return [] }
            return try await self.performFetch()
        }
        loadTask = task
        defer { loadTask = nil }

        return try await task.value
    }

    private func performFetch() async throws -> [SupportedVersion] {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/supported-versions"))
        request.httpMethod = "GET"
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SupportedVersionsError.serverError
        }

        let decoded = try decoder.decode(SupportedVersionsResponse.self, from: data)
        guard decoded.success else { throw SupportedVersionsError.decodingFailed }

        let list = decoded.versions ?? []
        SupportedVersionsStore.replace(list)
        lastFetch = Date()
        return list
    }

    /// Force refresh dari server
    func refresh() async throws -> [SupportedVersion] {
        try await fetch(force: true)
    }
}

enum SupportedVersionsError: Error, LocalizedError {
    case serverError
    case decodingFailed
    case networkUnreachable

    var errorDescription: String? {
        switch self {
        case .serverError: return "Server error"
        case .decodingFailed: return "Invalid response"
        case .networkUnreachable: return "No connection"
        }
    }
}
