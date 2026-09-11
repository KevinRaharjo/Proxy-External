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
        case .invalidURL: return "Konfigurasi server tidak valid."
        case .networkUnreachable: return "Server tidak dapat dijangkau. Periksa koneksi internet."
        case .serverError(let code): return "Server error (\(code))."
        case .decodingFailed: return "Respon server tidak valid."
        case .maintenance(let message): return message
        case .unknown: return "Terjadi kesalahan tidak dikenal."
        }
    }
}

// MARK: - API Client

actor APIClient {
    static let shared = APIClient()

    // ⚠️ GANTI DENGAN DOMAIN VPS KAMU
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

    /// Aktifkan key baru + bind ke device.
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

    /// Verifikasi session token yang sudah tersimpan.
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

    /// Unbind device dari key (logout / pindah device).
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

    /// Cek status server — maintenance atau tidak.
    func status() async throws -> ServerStatusResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/status"))
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
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
        try validate(response: response, data: data)

        // Cek maintenance khusus untuk endpoint activate/verify
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 503 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                throw APIClientError.maintenance(errorMsg)
            }
            throw APIClientError.maintenance("Server sedang dalam maintenance.")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIClientError.decodingFailed
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.networkUnreachable
        }
        // 503 ditangani di atas; yang lain:
        guard (200..<500).contains(httpResponse.statusCode) else {
            throw APIClientError.serverError(httpResponse.statusCode)
        }
    }
}
