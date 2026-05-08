import Foundation

struct LeaderboardWeek: Decodable {
    let id: UUID
    let weekStartDate: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case weekStartDate = "week_start_date"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        weekStartDate = try Self.decodeDate(from: container, forKey: .weekStartDate)
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