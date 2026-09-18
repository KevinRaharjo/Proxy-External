import Foundation

// ═══════════════════════════════════════════════
// MARK: - Models
// ═══════════════════════════════════════════════

struct ActivateResponse: Decodable {
    let success: Bool
    let token: String?
    let expiresAt: Date?
    let error: String?
    let firstActivation: Bool?

    enum CodingKeys: String, CodingKey {
        case success, token, expiresAt, error, firstActivation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decode(Bool.self, forKey: .success)) ?? false
        token = try? c.decode(String.self, forKey: .token)
        error = try? c.decode(String.self, forKey: .error)
        firstActivation = try? c.decode(Bool.self, forKey: .firstActivation)
        expiresAt = Self.decodeFlexibleDate(from: c, key: .expiresAt)
    }

    private static func decodeFlexibleDate(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Date? {
        guard let dateString = try? container.decode(String.self, forKey: key) else {
            return nil
        }
        let iso1 = ISO8601DateFormatter()
        iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso1.date(from: dateString) { return d }

        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        if let d = iso2.date(from: dateString) { return d }

        let sqlite = DateFormatter()
        sqlite.dateFormat = "yyyy-MM-dd HH:mm:ss"
        sqlite.timeZone = TimeZone(identifier: "UTC")
        if let d = sqlite.date(from: dateString) { return d }

        return nil
    }
}

struct VerifyResponse: Decodable {
    let success: Bool
    let expiresAt: Date?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success, expiresAt, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decode(Bool.self, forKey: .success)) ?? false
        error = try? c.decode(String.self, forKey: .error)

        if let dateString = try? c.decode(String.self, forKey: .expiresAt) {
            let iso1 = ISO8601DateFormatter()
            iso1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let iso2 = ISO8601DateFormatter()
            iso2.formatOptions = [.withInternetDateTime]
            let sqlite = DateFormatter()
            sqlite.dateFormat = "yyyy-MM-dd HH:mm:ss"
            sqlite.timeZone = TimeZone(identifier: "UTC")

            if let d = iso1.date(from: dateString) { expiresAt = d }
            else if let d = iso2.date(from: dateString) { expiresAt = d }
            else if let d = sqlite.date(from: dateString) { expiresAt = d }
            else { expiresAt = nil }
        } else {
            expiresAt = nil
        }
    }
}

struct DeactivateResponse: Decodable {
    let success: Bool
    let error: String?
}

struct ServerStatusResponse: Decodable {
    let online: Bool
    let maintenance: Bool
    let message: String?

    enum CodingKeys: String, CodingKey {
        case online, maintenance, message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        online = (try? c.decode(Bool.self, forKey: .online)) ?? true
        maintenance = (try? c.decode(Bool.self, forKey: .maintenance)) ?? false
        message = try? c.decode(String.self, forKey: .message)
    }
}

struct LicenseDeviceInfo: Codable {
    let deviceID: String
    let deviceName: String
    let deviceModel: String
    let osVersion: String
}

struct ServerPatchMetadata: Decodable, Identifiable {
    let id: Int
    let name: String
    let displayName: String
    let target: String
    let category: String
    let filename: String
    let size: Int
    let checksum: String
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, displayName, target, category, filename, size, checksum, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? name
        target = (try? c.decode(String.self, forKey: .target)) ?? ""
        category = (try? c.decode(String.self, forKey: .category)) ?? "AIM"
        filename = (try? c.decode(String.self, forKey: .filename)) ?? ""
        size = (try? c.decode(Int.self, forKey: .size)) ?? 0
        checksum = (try? c.decode(String.self, forKey: .checksum)) ?? ""

        if let dateStr = try? c.decode(String.self, forKey: .updatedAt) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            updatedAt = iso.date(from: dateStr)
        } else {
            updatedAt = nil
        }
    }
}

struct PatchListResponse: Decodable {
    let success: Bool
    let patches: [ServerPatchMetadata]?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success, patches, error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decode(Bool.self, forKey: .success)) ?? false
        patches = try? c.decode([ServerPatchMetadata].self, forKey: .patches)
        error = try? c.decode(String.self, forKey: .error)
    }
}

// MARK: - Errors

enum APIClientError: Error, LocalizedError {
    case invalidURL
    case networkUnreachable
    case serverError(Int)
    case decodingFailed
    case maintenance(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server configuration."
        case .networkUnreachable:
            return "Cannot reach server. Check your internet connection."
        case .serverError(let code):
            return "Server error (\(code)). Try again later."
        case .decodingFailed:
            return "Cannot process server response. Please update the app."
        case .maintenance(let message):
            return message
        case .unknown:
            return "Something went wrong. Try again."
        }
    }
}

// ═══════════════════════════════════════════════
// MARK: - API Client
// ═══════════════════════════════════════════════

actor APIClient {
    static let shared = APIClient()

    private let baseURL = URL(string: "https://api.proxynixx.my.id/")!

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    // ═══ Retry helper ═══
    private func performRequest<T: Decodable>(
        _ request: URLRequest,
        maxRetries: Int = 3
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw APIClientError.networkUnreachable
                }

                if http.statusCode >= 500 {
                    lastError = APIClientError.serverError(http.statusCode)
                    if attempt < maxRetries {
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                        continue
                    }
                }

                guard (200..<500).contains(http.statusCode) else {
                    throw APIClientError.serverError(http.statusCode)
                }

                if let raw = String(data: data, encoding: .utf8),
                   raw.trimmingCharacters(in: .whitespaces).hasPrefix("<") {
                    lastError = APIClientError.decodingFailed
                    if attempt < maxRetries {
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                        continue
                    }
                    throw APIClientError.decodingFailed
                }

                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw APIClientError.decodingFailed
                }
            } catch let error as APIClientError {
                lastError = error
                if attempt < maxRetries, case .networkUnreachable = error {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                    continue
                }
                throw error
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                    continue
                }
                throw APIClientError.networkUnreachable
            }
        }

        throw lastError ?? APIClientError.unknown
    }

    // ═══ License Endpoints ═══

    func activate(
        key: String,
        device: LicenseDeviceInfo
    ) async throws -> ActivateResponse {
        let body: [String: String] = [
            "key": key,
            "device_id": device.deviceID,
            "device_name": device.deviceName,
            "device_model": device.deviceModel,
            "os_version": device.osVersion
        ]
        return try await post(path: "/api/v1/activate", body: body)
    }

    func verify(token: String, deviceID: String) async throws -> VerifyResponse {
        let body: [String: String] = [
            "token": token,
            "device_id": deviceID
        ]
        return try await post(path: "/api/v1/verify", body: body)
    }

    func deactivate(token: String, deviceID: String) async throws -> DeactivateResponse {
        let body: [String: String] = [
            "token": token,
            "device_id": deviceID
        ]
        return try await post(path: "/api/v1/deactivate", body: body)
    }

    func status() async throws -> ServerStatusResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/status"))
        request.httpMethod = "GET"
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        return try await performRequest(request)
    }

    // ═══ Patches ═══

    func fetchPatchList(
        deviceID: String,
        license: String,
        target: String? = nil
    ) async throws -> [ServerPatchMetadata] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/patches/list"),
            resolvingAgainstBaseURL: false
        )!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "device_id", value: deviceID),
            URLQueryItem(name: "license", value: license)
        ]
        if let target {
            queryItems.append(URLQueryItem(name: "target", value: target))
        }
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let response: PatchListResponse = try await performRequest(request)
        guard response.success else {
            throw APIClientError.serverError(0)
        }
        return response.patches ?? []
    }

    func downloadPatch(id: Int, deviceID: String, license: String) async throws -> Data {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/api/v1/patches/download/\(id)"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "device_id", value: deviceID),
            URLQueryItem(name: "license", value: license)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.networkUnreachable
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIClientError.serverError(http.statusCode)
        }
        return data
    }

    // ═══ Private POST ═══

    private func post<T: Decodable>(
        path: String,
        body: [String: String]
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try encoder.encode(body)
        request.timeoutInterval = 30

        return try await performRequest(request)
    }
}
