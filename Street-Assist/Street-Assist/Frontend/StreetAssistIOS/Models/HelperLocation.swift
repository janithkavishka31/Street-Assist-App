import Foundation
import CoreLocation

struct HelperLocation: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let latitude: Double
    let longitude: Double
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case latitude
        case longitude
        case updatedAt = "updated_at"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
