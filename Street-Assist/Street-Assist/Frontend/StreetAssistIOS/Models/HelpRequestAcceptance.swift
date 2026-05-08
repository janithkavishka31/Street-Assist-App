import Foundation

struct HelpRequestAcceptance: Codable {
    let id: UUID
    let requestId: UUID
    let helperUserId: UUID
    let acceptedAt: Date
    let completedAt: Date?
    let canceledAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case requestId = "request_id"
        case helperUserId = "helper_user_id"
        case acceptedAt = "accepted_at"
        case completedAt = "completed_at"
        case canceledAt = "canceled_at"
    }
}