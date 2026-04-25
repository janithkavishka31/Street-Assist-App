import Foundation

struct HelpRequestPhoto: Codable {
    let id: UUID
    let requestId: UUID
    let photoUrl: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case requestId = "request_id"
        case photoUrl = "photo_url"
        case sortOrder = "sort_order"
    }
}