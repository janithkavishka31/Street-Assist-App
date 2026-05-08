import Foundation

struct HelpZone: Codable, Identifiable, Hashable {
    let id: UUID
    let zoneName: String
    let organizationName: String
    let joinCode: String
    let verificationStatus: VerificationStatus
    let createdByUserId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case zoneName = "zone_name"
        case organizationName = "organization_name"
        case joinCode = "join_code"
        case verificationStatus = "verification_status"
        case createdByUserId = "created_by_user_id"
        case createdAt = "created_at"
    }
}