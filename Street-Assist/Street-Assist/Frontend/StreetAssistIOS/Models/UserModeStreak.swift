import Foundation

struct UserModeStreak: Decodable, Identifiable {
    let id: UUID
    let userId: UUID
    let mode: LeaderboardMode
    let currentStreakDays: Int
    let bestStreakDays: Int
    let lastCheckinDate: Date?
    let weeklyStreakCompletedAt: Date?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mode
        case currentStreakDays = "current_streak_days"
        case bestStreakDays = "best_streak_days"
        case lastCheckinDate = "last_checkin_date"
        case weeklyStreakCompletedAt = "weekly_streak_completed_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        mode = try container.decode(LeaderboardMode.self, forKey: .mode)
        currentStreakDays = try container.decode(Int.self, forKey: .currentStreakDays)
        bestStreakDays = try container.decode(Int.self, forKey: .bestStreakDays)
        lastCheckinDate = try Self.decodeOptionalDate(from: container, forKey: .lastCheckinDate)
        weeklyStreakCompletedAt = try Self.decodeOptionalDate(from: container, forKey: .weeklyStreakCompletedAt)
        updatedAt = try Self.decodeDate(from: container, forKey: .updatedAt)
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

    private static let iso8601NoFractionFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let fallbackTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter
    }()

    private static func decodeDate<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) throws -> Date {
        let string = try container.decode(String.self, forKey: key)
        if let date = parseDate(string) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Unsupported date format: \(string)"
        )
    }

    private static func decodeOptionalDate<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) throws -> Date? {
        guard let string = try container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }

        return parseDate(string)
    }

    private static func parseDate(_ string: String) -> Date? {
        iso8601Formatter.date(from: string)
            ?? iso8601NoFractionFormatter.date(from: string)
            ?? fallbackTimestampFormatter.date(from: string)
            ?? dateOnlyFormatter.date(from: string)
    }
}
