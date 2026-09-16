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
}

enum AnnouncementPriority: String, Codable {
    case low, normal, high
}

struct AnnouncementResponse: Codable {
    let success: Bool
    let announcements: [Announcement]?
}
