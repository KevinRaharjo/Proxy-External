import Foundation

struct Announcement: Identifiable, Codable, Equatable {
    let id: Int
    let title: String
    let body: String
    let type: AnnouncementType
    let priority: AnnouncementPriority
    let pinned: Bool
    let actionLabel: String?
    let actionUrl: String?
    let publishedAt: Date?
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, body, type, priority, pinned
        case actionLabel = "actionLabel"
        case actionUrl = "actionUrl"
        case publishedAt = "publishedAt"
        case expiresAt = "expiresAt"
    }
}

enum AnnouncementPriority: String, Codable {
    case low, normal, high

    var weight: Int {
        switch self {
        case .low:    return 0
        case .normal: return 1
        case .high:   return 2
        }
    }
}

struct AnnouncementResponse: Codable {
    let success: Bool
    let announcements: [Announcement]?
}
