import Foundation

struct HelpRequest: Codable, Identifiable, Hashable {
    let id: UUID
    let requesterUserId: UUID
    let category: HelpCategory
    let serviceTitle: String
    let description: String
    let latitude: Double
    let longitude: Double
    let scope: RequestScope
    let zoneId: UUID?
    let status: RequestStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case requesterUserId = "requester_user_id"
        case category
        case serviceTitle = "service_title"
        case description
        case latitude
        case longitude
        case scope
        case zoneId = "zone_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}