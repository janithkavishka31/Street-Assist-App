import Foundation

struct LeaderboardWeek: Codable {
    let id: UUID
    let weekStartDate: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case weekStartDate = "week_start_date"
        case createdAt = "created_at"
    }
}