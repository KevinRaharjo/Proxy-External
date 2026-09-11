import Foundation

// MARK: - Models

struct ActivateResponse: Decodable {
    let success: Bool
    let token: String?
    let expiresAt: Date?
    let error: String?
}

struct VerifyResponse: Decodable {
    let success: Bool
    let expiresAt: Date?
    let error: String?
}

struct DeactivateResponse: Decodable {
    let success: Bool
    let error: String?
}

struct ServerStatusResponse: Decodable {
    let online: Bool
    let maintenance: Bool
    let message: String?
}

struct LicenseDeviceInfo: Codable {
    let deviceID: String
    let deviceName: String
    let deviceModel: String
    let osVersion: String
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
        case .invalidURL: return "Invalid server configuration."
        case .networkUnreachable: return "Server unreachable. Check your internet connection."
        case .serverError(let code): return "Server error (\(code))."
        case .decodingFailed: return "Invalid server response."
        case .maintenance(let message): return message
        case .unknown: return "An unknown error occurred."
        }
    }
}

// MARK: - API Client

actor APIClient {
    static let shared = APIClient()

    // ⚠️ CHANGE THIS TO YOUR VPS DOMAIN
    private let baseURL = URL(string: "https://api.nixxtime.com")!

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
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

    // MARK: - Public Endpoints

    /// Activate new key + bind to device.
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

    /// Verify a stored session token.
    func verify(
        token: String,
        deviceID: String
    ) async throws -> VerifyResponse {
        let body: [String: String] = [
            "token": token,
            "device_id": deviceID
        ]
        return try await post(path: "/api/v1/verify", body: body)
    }

    /// Unbind device from key (logout / switch device).
    func deactivate(
        token: String,
        deviceID: String
    ) async throws -> DeactivateResponse {
        let body: [String: String] = [
            "token": token,
            "device_id": deviceID
        ]
        return try await post(path: "/api/v1/deactivate", body: body)
    }

    /// Check server status — maintenance or not.
    /// This endpoint is safe to call when maintenance is active (returns 200).
    func status() async throws -> ServerStatusResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/status"))
        request.httpMethod = "GET"
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.networkUnreachable
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(ServerStatusResponse.self, from: data)
        } catch {
            throw APIClientError.decodingFailed
        }
    }

    // MARK: - Private

    private func post<T: Decodable>(
        path: String,
        body: [String: String]
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.networkUnreachable
        }

        // Handle 503 maintenance specifically
        if httpResponse.statusCode == 503 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                throw APIClientError.maintenance(errorMsg)
            }
            throw APIClientError.maintenance("Server is under maintenance.")
        }

        guard (200..<500).contains(httpResponse.statusCode) else {
            throw APIClientError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingFailed
        }
    }
}
