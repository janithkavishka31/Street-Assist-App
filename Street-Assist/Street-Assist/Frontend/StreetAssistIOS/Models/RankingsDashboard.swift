import Foundation

struct RankingsLeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let title: String?
    let points: Int
    let highlight: Bool
}

struct RankingsDashboard {
    let totalPoints: Int
    let currentStreakDays: Int
    let bestStreakDays: Int
    let weeklyLeaderboard: [RankingsLeaderboardEntry]
    let activeVoucher: DiscountVoucher?
    let canClaimTopTenVoucher: Bool

    var giftUnlocked: Bool {
        currentStreakDays >= 7
    }
}
