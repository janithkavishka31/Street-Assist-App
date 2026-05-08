import Foundation

struct UserSkill: Codable {
    let userId: UUID
    let skillId: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case skillId = "skill_id"
        case createdAt = "created_at"
    }
}