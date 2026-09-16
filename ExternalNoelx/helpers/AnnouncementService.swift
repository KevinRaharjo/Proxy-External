import Foundation

actor AnnouncementService {
    static let shared = AnnouncementService()

    private let baseURL = URL(string: "https://api.proxynixx.my.id/")!
    private let session: URLSession
    private let decoder: JSONDecoder
    private var cache: [Announcement] = []
    private var lastFetch: Date?
    private let cacheTTL: TimeInterval = 60

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
    }

    func fetch(force: Bool = false) async throws -> [Announcement] {
        if !force, let last = lastFetch, Date().timeIntervalSince(last) < cacheTTL {
            return cache
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/v1/announcements"))
        request.httpMethod = "GET"
        request.setValue("NixxTime-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AnnouncementError.serverError
        }

        let decoded = try decoder.decode(AnnouncementResponse.self, from: data)
        guard decoded.success else { throw AnnouncementError.decodingFailed }

        let list = decoded.announcements ?? []
        cache = list
        lastFetch = Date()
        return list
    }

    func cached() -> [Announcement] { cache }
}

enum AnnouncementError: Error, LocalizedError {
    case serverError
    case decodingFailed
    case networkUnreachable

    var errorDescription: String? {
        switch self {
        case .serverError:       return "Server error"
        case .decodingFailed:    return "Invalid response"
        case .networkUnreachable:return "No connection"
        }
    }
}
