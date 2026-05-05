import Foundation

struct HelpRequestRating: Codable, Identifiable {
    let id: UUID
    let requestId: UUID
    let raterUserId: UUID
    let ratedUserId: UUID
    let score: Int
    let comment: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requestId = "request_id"
        case raterUserId = "rater_user_id"
        case ratedUserId = "rated_user_id"
        case score
        case comment
        case createdAt = "created_at"
    }
}
