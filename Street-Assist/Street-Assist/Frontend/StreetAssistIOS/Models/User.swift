import Foundation

struct User: Codable {
    let id: UUID
    let fullName: String
    let email: String?
    let phone: String?
    let quickBio: String?
    let agreedToTerms: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case phone
        case quickBio = "quick_bio"
        case agreedToTerms = "agreed_to_terms"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}