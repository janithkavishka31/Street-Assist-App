import SwiftUI

struct RankingsView: View {
    enum Mode: String, CaseIterable {
        case helper = "Helper"
        case requester = "Requester"
    }

    var onBack: (() -> Void)?

    @State private var selectedMode: Mode = .helper

    private let weeklyLeaderboard: [LeaderboardEntry] = [
        .init(rank: 1, name: "Alex G.", title: "Platinum Helper", points: 140),
        .init(rank: 2, name: "Maria K.", title: "Elite Guardian", points: 128),
        .init(rank: 3, name: "James L.", title: "Steady Pulse", points: 115),
        .init(rank: 4, name: "Sarah Jenkins", title: nil, points: 98),
        .init(rank: 5, name: "David Chen", title: nil, points: 87),
        .init(rank: 6, name: "You", title: nil, points: 82, highlight: true),
    ]

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(
                title: "Rankings",
                leadingStyle: .back,
                trailingStyle: .avatar,
                onBackTap: { onBack?() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    modePicker
                        .padding(.top, 12)

                    currentProgress

                    streakCard

                    weeklyReward
                        .padding(.top, 8)

                    weeklyLeaderboardSection
                        .padding(.top, 10)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .background(AppTheme.screenBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.self) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(selectedMode == mode ? Color.white : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Group {
                                if selectedMode == mode {
                                    AppTheme.primaryBlue
                                } else {
                                    Color.white
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
    }

    private var currentProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CURRENT PROGRESS")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.primaryBlue)
                .tracking(1.2)

            Text("You're on fire! 5-day\nstreak.")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineSpacing(2)
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Personal Best: My Streak")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Unlock a special reward at 7 days!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.categoryOrangeBackground, lineWidth: 6)
                            )
                            .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)

                        Image(systemName: "gift.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.categoryOrange)

                        Text("LOCKED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.75))
                            .clipShape(Capsule())
                            .offset(y: -28)
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("7-DAY GIFT")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.categoryOrange)

                        Text("Reach Day 7")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            HStack {
                Text("PROGRESS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)
                    .tracking(0.8)

                Spacer()

                Text("5/7 DAYS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)
                    .tracking(0.8)
            }

            ProgressPillsView(current: 5, total: 7)

            HStack {
                ForEach(1...7, id: \.self) { day in
                    Text("D\(day)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(day == 7 ? AppTheme.primaryBlue : AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
    }

    private var weeklyReward: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly Reward")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button {
                    // wired later
                } label: {
                    Text("View all")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlue)
                }
                .buttonStyle(.plain)
            }

            WeeklyRewardCardView()
        }
    }

    private var weeklyLeaderboardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly Leaderboard")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(AppTheme.liveGreen)
                        .frame(width: 8, height: 8)

                    Text("LIVE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
            }

            LeaderboardCardView(entries: weeklyLeaderboard)
        }
    }
}

private struct ProgressPillsView: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index < current ? AppTheme.primaryBlue : Color.black.opacity(0.12))
                    .frame(height: 8)
            }
        }
    }
}

private struct WeeklyRewardCardView: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primaryBlue, AppTheme.primaryBlueDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 240, height: 240)
                .offset(x: 160, y: 40)

            VStack(alignment: .leading, spacing: 14) {
                Text("ACTIVE PERK")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .tracking(1.0)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())

                Text("20% Off")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.white)

                Text("App Service Fees")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.95))

                Text("Top 10 placement reward for Week 42.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .padding(.top, 2)

                Spacer(minLength: 0)
            }
            .padding(22)
        }
        .frame(height: 210)
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
    }
}

private struct LeaderboardEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let title: String?
    let points: Int
    var highlight: Bool = false
}

private struct LeaderboardCardView: View {
    let entries: [LeaderboardEntry]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(entries) { entry in
                if entry.rank <= 3 {
                    TopLeaderboardRow(entry: entry)
                } else {
                    StandardLeaderboardRow(entry: entry)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 16, x: 0, y: 12)
    }
}

private struct TopLeaderboardRow: View {
    let entry: LeaderboardEntry

    private var badgeStroke: Color {
        switch entry.rank {
        case 1: return AppTheme.categoryOrangeBackground
        case 2: return Color.black.opacity(0.10)
        default: return Color.black.opacity(0.12)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 48, height: 48)

                Circle()
                    .stroke(badgeStroke, lineWidth: 5)
                    .frame(width: 48, height: 48)

                Text("\(entry.rank)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(entry.title ?? "")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.points)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)

                Text("PTS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct StandardLeaderboardRow: View {
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("\(entry.rank)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 18, alignment: .leading)

            Text(entry.name)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer(minLength: 0)

            Text("\(entry.points) pts")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(entry.highlight ? AppTheme.primaryBlue : AppTheme.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.clear)
    }
}

#Preview {
    NavigationStack {
        RankingsView(onBack: {})
            .toolbar(.hidden, for: .navigationBar)
    }
}
