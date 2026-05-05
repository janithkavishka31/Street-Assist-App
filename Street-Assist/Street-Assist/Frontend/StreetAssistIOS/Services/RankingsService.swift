import Foundation
import Supabase

final class RankingsService {
    static let shared = RankingsService()

    private init() {}

    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    func fetchDashboard(mode: LeaderboardMode) async throws -> RankingsDashboard {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "RankingsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        try? await syncDailyCheckInFromActivity(mode: mode)

        let totalPoints: Int
        do {
            totalPoints = try await fetchTotalPoints(userId: userId)
        } catch {
            print("❌ RankingsService: fetchTotalPoints failed - \(error)")
            throw NSError(domain: "RankingsService", code: 10, userInfo: [NSLocalizedDescriptionKey: "user_gamification table may not exist. Please apply the SQL schema patch. Error: \(error.localizedDescription)"])
        }

        let streak: UserModeStreak?
        do {
            streak = try await fetchModeStreak(userId: userId, mode: mode)
        } catch {
            print("❌ RankingsService: fetchModeStreak failed - \(error)")
            throw NSError(domain: "RankingsService", code: 11, userInfo: [NSLocalizedDescriptionKey: "user_mode_streaks table may not exist. Please apply the SQL schema patch. Error: \(error.localizedDescription)"])
        }

        let week: LeaderboardWeek
        do {
            week = try await fetchOrCreateCurrentWeek()
        } catch {
            print("❌ RankingsService: fetchOrCreateCurrentWeek failed - \(error)")
            throw NSError(domain: "RankingsService", code: 12, userInfo: [NSLocalizedDescriptionKey: "leaderboard_weeks table may not exist. Please apply the SQL schema patch. Error: \(error.localizedDescription)"])
        }

        let weeklyEntries: [RankingsLeaderboardEntry]
        do {
            weeklyEntries = try await fetchWeeklyLeaderboardEntries(weekId: week.id, mode: mode, currentUserId: userId)
        } catch {
            print("❌ RankingsService: fetchWeeklyLeaderboardEntries failed - \(error)")
            throw NSError(domain: "RankingsService", code: 13, userInfo: [NSLocalizedDescriptionKey: "leaderboard_entries table may not exist. Please apply the SQL schema patch. Error: \(error.localizedDescription)"])
        }

        let activeVoucher: DiscountVoucher?
        do {
            activeVoucher = try await fetchActiveVoucher(userId: userId, mode: mode)
        } catch {
            print("❌ RankingsService: fetchActiveVoucher failed - \(error)")
            throw NSError(domain: "RankingsService", code: 14, userInfo: [NSLocalizedDescriptionKey: "discount_vouchers table may not exist. Please apply the SQL schema patch. Error: \(error.localizedDescription)"])
        }

        let canClaimTopTenVoucher = weeklyEntries.contains(where: { $0.highlight && $0.rank <= 10 })
            && activeVoucher?.source != "weekly_top10"

        return RankingsDashboard(
            totalPoints: totalPoints,
            currentStreakDays: streak?.currentStreakDays ?? 0,
            bestStreakDays: streak?.bestStreakDays ?? 0,
            weeklyLeaderboard: weeklyEntries,
            activeVoucher: activeVoucher,
            canClaimTopTenVoucher: canClaimTopTenVoucher
        )
    }

    func claimTopTenVoucher(mode: LeaderboardMode) async throws -> DiscountVoucher {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "RankingsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let dashboard = try await fetchDashboard(mode: mode)
        guard dashboard.weeklyLeaderboard.contains(where: { $0.highlight && $0.rank <= 10 }) else {
            throw NSError(domain: "RankingsService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not eligible for Top 10 voucher this week"])
        }

        let now = Date()
        let validUntil = Calendar.current.date(byAdding: .day, value: 3, to: now) ?? now

        let voucherData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "mode": .string(mode.rawValue),
            "source": .string("weekly_top10"),
            "discount_percent": .integer(20),
            "valid_from": .string(now.ISO8601Format()),
            "valid_until": .string(validUntil.ISO8601Format()),
            "is_used": .bool(false)
        ]

        let voucher: DiscountVoucher = try await SupabaseManager.shared.client
            .from("discount_vouchers")
            .insert(voucherData)
            .select()
            .single()
            .execute()
            .value

        return voucher
    }

    func openGiftBox(mode: LeaderboardMode) async throws -> DiscountVoucher {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "RankingsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let streak = try await fetchModeStreak(userId: userId, mode: mode)
        guard (streak?.currentStreakDays ?? 0) >= 7 else {
            throw NSError(domain: "RankingsService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Complete 7-day streak to open gift box"])
        }

        let discount = randomGiftDiscount()
        let now = Date()
        let validUntil = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        let voucherData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "mode": .string(mode.rawValue),
            "source": .string("gift_box"),
            "discount_percent": .integer(discount),
            "valid_from": .string(now.ISO8601Format()),
            "valid_until": .string(validUntil.ISO8601Format()),
            "is_used": .bool(false)
        ]

        let voucher: DiscountVoucher = try await SupabaseManager.shared.client
            .from("discount_vouchers")
            .insert(voucherData)
            .select()
            .single()
            .execute()
            .value

        return voucher
    }

    func recordPaymentCompletion(requestId: UUID, helperUserId: UUID, requesterUserId: UUID) async throws {
        try await ensureCheckInAndPoints(
            userId: helperUserId,
            mode: .helper,
            points: 10,
            requestId: requestId
        )
        try await ensureCheckInAndPoints(
            userId: requesterUserId,
            mode: .requester,
            points: 10,
            requestId: requestId
        )
    }

    private func randomGiftDiscount() -> Int {
        let pool = [5, 5, 5, 10, 10, 20]
        return pool.randomElement() ?? 5
    }

    private func fetchTotalPoints(userId: UUID) async throws -> Int {
        struct GamificationRow: Codable {
            let totalPoints: Int

            enum CodingKeys: String, CodingKey {
                case totalPoints = "total_points"
            }
        }

        let rows: [GamificationRow] = try await SupabaseManager.shared.client
            .from("user_gamification")
            .select("total_points")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first?.totalPoints ?? 0
    }

    private func fetchModeStreak(userId: UUID, mode: LeaderboardMode) async throws -> UserModeStreak? {
        let rows: [UserModeStreak] = try await SupabaseManager.shared.client
            .from("user_mode_streaks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("mode", value: mode.rawValue)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    private func fetchOrCreateCurrentWeek() async throws -> LeaderboardWeek {
        let weekStart = startOfCurrentWeekSunday(from: Date())
        let weekStartDateString = Self.dateOnlyFormatter.string(from: weekStart)

        let existing: [LeaderboardWeek] = try await SupabaseManager.shared.client
            .from("leaderboard_weeks")
            .select()
            .eq("week_start_date", value: weekStartDateString)
            .limit(1)
            .execute()
            .value

        if let week = existing.first {
            return week
        }

        let insertData: [String: AnyJSON] = [
            "week_start_date": .string(weekStartDateString)
        ]

        let created: LeaderboardWeek = try await SupabaseManager.shared.client
            .from("leaderboard_weeks")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    private func fetchWeeklyLeaderboardEntries(weekId: UUID, mode: LeaderboardMode, currentUserId: UUID) async throws -> [RankingsLeaderboardEntry] {
        struct LeaderboardEntryRow: Codable {
            let userId: UUID
            let points: Int
            let rank: Int
            let titleLabel: String?

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case points
                case rank
                case titleLabel = "title_label"
            }
        }

        let rows: [LeaderboardEntryRow] = try await SupabaseManager.shared.client
            .from("leaderboard_entries")
            .select("user_id, points, rank, title_label")
            .eq("leaderboard_week_id", value: weekId.uuidString)
            .eq("mode", value: mode.rawValue)
            .order("rank", ascending: true)
            .limit(20)
            .execute()
            .value

        if rows.isEmpty {
            return []
        }

        struct UserNameRow: Codable {
            let id: UUID
            let fullName: String

            enum CodingKeys: String, CodingKey {
                case id
                case fullName = "full_name"
            }
        }

        let userIds = rows.map { $0.userId.uuidString }
        let users: [UserNameRow] = try await SupabaseManager.shared.client
            .from("users")
            .select("id, full_name")
            .in("id", values: userIds)
            .execute()
            .value

        let nameMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0.fullName) })

        return rows.map { row in
            RankingsLeaderboardEntry(
                rank: row.rank,
                name: nameMap[row.userId] ?? "Anonymous",
                title: row.titleLabel,
                points: row.points,
                highlight: row.userId == currentUserId
            )
        }
    }

    private func fetchActiveVoucher(userId: UUID, mode: LeaderboardMode) async throws -> DiscountVoucher? {
        let vouchers: [DiscountVoucher] = try await SupabaseManager.shared.client
            .from("discount_vouchers")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("mode", value: mode.rawValue)
            .eq("is_used", value: false)
            .gt("valid_until", value: Date().ISO8601Format())
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        return vouchers.first
    }

    private func syncDailyCheckInFromActivity(mode: LeaderboardMode) async throws {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today

        let hasActivityToday: Bool
        if mode == .helper {
            let acceptances: [HelpRequestAcceptance] = try await SupabaseManager.shared.client
                .from("help_request_acceptances")
                .select()
                .eq("helper_user_id", value: userId.uuidString)
                .gte("accepted_at", value: today.ISO8601Format())
                .lt("accepted_at", value: tomorrow.ISO8601Format())
                .limit(1)
                .execute()
                .value
            hasActivityToday = !acceptances.isEmpty
        } else {
            let requests: [HelpRequest] = try await SupabaseManager.shared.client
                .from("help_requests")
                .select()
                .eq("requester_user_id", value: userId.uuidString)
                .gte("created_at", value: today.ISO8601Format())
                .lt("created_at", value: tomorrow.ISO8601Format())
                .limit(1)
                .execute()
                .value
            hasActivityToday = !requests.isEmpty
        }

        guard hasActivityToday else { return }

        let dateKey = Self.dateOnlyFormatter.string(from: today)
        let checkinData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "mode": .string(mode.rawValue),
            "check_in_date": .string(dateKey)
        ]

        do {
            _ = try await SupabaseManager.shared.client
                .from("user_daily_checkins")
                .insert(checkinData)
                .execute()

            try await updateStreakAfterSuccessfulCheckIn(userId: userId, mode: mode, date: today)
            try await addPoints(userId: userId, points: 5, reason: .bonus, requestId: nil)
        } catch {
            // unique violation means today's check-in already exists; ignore
        }
    }

    private func updateStreakAfterSuccessfulCheckIn(userId: UUID, mode: LeaderboardMode, date: Date) async throws {
        let existing = try await fetchModeStreak(userId: userId, mode: mode)
        let today = Calendar.current.startOfDay(for: date)

        let newCurrent: Int
        let newBest: Int

        if let existing,
           let lastCheckin = existing.lastCheckinDate {
            let last = Calendar.current.startOfDay(for: lastCheckin)
            if Calendar.current.isDate(last, inSameDayAs: today) {
                return
            }

            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)
            if let yesterday, Calendar.current.isDate(last, inSameDayAs: yesterday) {
                newCurrent = existing.currentStreakDays + 1
            } else {
                newCurrent = 1
            }
            newBest = max(existing.bestStreakDays, newCurrent)

            let updateData: [String: AnyJSON] = [
                "current_streak_days": .integer(newCurrent),
                "best_streak_days": .integer(newBest),
                "last_checkin_date": .string(Self.dateOnlyFormatter.string(from: today)),
                "weekly_streak_completed_at": newCurrent >= 7 ? .string(Date().ISO8601Format()) : .null,
                "updated_at": .string(Date().ISO8601Format())
            ]

            _ = try await SupabaseManager.shared.client
                .from("user_mode_streaks")
                .update(updateData)
                .eq("id", value: existing.id.uuidString)
                .execute()
            return
        }

        let insertData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "mode": .string(mode.rawValue),
            "current_streak_days": .integer(1),
            "best_streak_days": .integer(1),
            "last_checkin_date": .string(Self.dateOnlyFormatter.string(from: today)),
            "updated_at": .string(Date().ISO8601Format())
        ]

        _ = try await SupabaseManager.shared.client
            .from("user_mode_streaks")
            .insert(insertData)
            .execute()
    }

    private func addPoints(userId: UUID, points: Int, reason: PointsReason, requestId: UUID?) async throws {
        let ledgerData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "points": .integer(points),
            "reason": .string(reason.rawValue),
            "request_id": requestId.map { .string($0.uuidString) } ?? .null
        ]

        _ = try await SupabaseManager.shared.client
            .from("points_ledger")
            .insert(ledgerData)
            .execute()

        struct GamificationRow: Codable {
            let userId: UUID
            let totalPoints: Int

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case totalPoints = "total_points"
            }
        }

        let rows: [GamificationRow] = try await SupabaseManager.shared.client
            .from("user_gamification")
            .select("user_id, total_points")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        if let row = rows.first {
            let updateData: [String: AnyJSON] = [
                "total_points": .integer(row.totalPoints + points),
                "updated_at": .string(Date().ISO8601Format())
            ]

            _ = try await SupabaseManager.shared.client
                .from("user_gamification")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .execute()
        } else {
            let insertData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "total_points": .integer(points),
                "weekly_assists": .integer(0),
                "current_streak_days": .integer(0),
                "best_streak_days": .integer(0),
                "updated_at": .string(Date().ISO8601Format())
            ]

            _ = try await SupabaseManager.shared.client
                .from("user_gamification")
                .insert(insertData)
                .execute()
        }
    }

    private func startOfCurrentWeekSunday(from date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let isoWeekStart = calendar.date(from: components) ?? date
        return calendar.date(byAdding: .day, value: -1, to: isoWeekStart) ?? isoWeekStart
    }

    private func ensureCheckInAndPoints(userId: UUID, mode: LeaderboardMode, points: Int, requestId: UUID) async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let dateKey = Self.dateOnlyFormatter.string(from: today)

        let existingCheckins: [UserDailyCheckinRow] = try await SupabaseManager.shared.client
            .from("user_daily_checkins")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("mode", value: mode.rawValue)
            .eq("check_in_date", value: dateKey)
            .limit(1)
            .execute()
            .value

        if existingCheckins.isEmpty {
            let checkinData: [String: AnyJSON] = [
                "user_id": .string(userId.uuidString),
                "mode": .string(mode.rawValue),
                "check_in_date": .string(dateKey)
            ]

            _ = try await SupabaseManager.shared.client
                .from("user_daily_checkins")
                .insert(checkinData)
                .execute()

            try await updateStreakAfterSuccessfulCheckIn(userId: userId, mode: mode, date: today)
        }

        let existingLedgerRows: [PointsLedgerRow] = try await SupabaseManager.shared.client
            .from("points_ledger")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("request_id", value: requestId.uuidString)
            .eq("reason", value: PointsReason.assistCompleted.rawValue)
            .limit(1)
            .execute()
            .value

        if existingLedgerRows.isEmpty {
            try await addPoints(
                userId: userId,
                points: points,
                reason: .assistCompleted,
                requestId: requestId
            )
        }
    }
}

private struct UserDailyCheckinRow: Decodable {
    let id: UUID
}

private struct PointsLedgerRow: Decodable {
    let id: UUID
}
