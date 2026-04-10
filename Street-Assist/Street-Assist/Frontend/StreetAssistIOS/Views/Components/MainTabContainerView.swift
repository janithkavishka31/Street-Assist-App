import SwiftUI

struct MainTabContainerView: View {
    @State private var selectedTab: StreetAssistTab = .home
    @StateObject private var session = AppSession()

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                Group {
                    switch selectedTab {
                    case .home:
                        HomeView()
                    case .incoming:
                        IncomingRequestsView()
                    case .zones:
                        HelpZonesView(onBack: { selectedTab = .home })
                    case .rankings:
                        RankingsView(onBack: { selectedTab = .home })
                    case .profile:
                        PlaceholderTabView(title: "Profile")
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
            .environmentObject(session)

            StreetAssistBottomTabBar(selected: $selectedTab)
        }
        .background(AppTheme.screenBackground)
    }
}

private struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(title: title, leadingStyle: .avatar, trailingStyle: .bell)

            Spacer()

            Text("Coming soon")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()
        }
        .background(AppTheme.screenBackground)
    }
}

#Preview {
    MainTabContainerView()
}
