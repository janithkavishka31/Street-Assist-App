import Foundation

struct UserSettings: Codable {
    let userId: UUID
    let isHelperEnabled: Bool
    let defaultScope: RequestScope
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isHelperEnabled = "is_helper_enabled"
        case defaultScope = "default_scope"
        case updatedAt = "updated_at"
    }
}