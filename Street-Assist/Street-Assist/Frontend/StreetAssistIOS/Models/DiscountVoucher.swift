import Foundation

struct DiscountVoucher: Decodable, Identifiable {
    let id: UUID
    let userId: UUID
    let mode: LeaderboardMode
    let source: String
    let discountPercent: Int
    let validFrom: Date
    let validUntil: Date
    let isUsed: Bool
    let requestId: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mode
        case source
        case discountPercent = "discount_percent"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case isUsed = "is_used"
        case requestId = "request_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        mode = try container.decode(LeaderboardMode.self, forKey: .mode)
        source = try container.decode(String.self, forKey: .source)
        discountPercent = try container.decode(Int.self, forKey: .discountPercent)
        validFrom = try Self.decodeDate(from: container, forKey: .validFrom)
        validUntil = try Self.decodeDate(from: container, forKey: .validUntil)
        isUsed = try container.decode(Bool.self, forKey: .isUsed)
        requestId = try container.decodeIfPresent(UUID.self, forKey: .requestId)
        createdAt = try Self.decodeDate(from: container, forKey: .createdAt)
    }

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func decodeDate<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) throws -> Date {
        let string = try container.decode(String.self, forKey: key)
        if let date = iso8601Formatter.date(from: string) ?? dateOnlyFormatter.date(from: string) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Unsupported date format: \(string)"
        )
    }
}
