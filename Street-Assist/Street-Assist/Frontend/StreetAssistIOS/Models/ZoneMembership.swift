import Foundation

struct ZoneMembership: Codable {
    let id: UUID
    let zoneId: UUID
    let userId: UUID
    let role: ZoneRole
    let status: ZoneMemberStatus
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case zoneId = "zone_id"
        case userId = "user_id"
        case role
        case status
        case joinedAt = "joined_at"
    }
}