import SwiftUI

enum StreetAssistTab: String, CaseIterable {
    case home = "Home"
    case incoming = "Incoming\nRequests"
    case zones = "Help-Zones"
    case rankings = "Rankings"
    case profile = "Profile"

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .incoming: return "text.bubble"
        case .zones: return "map"
        case .rankings: return "chart.bar"
        case .profile: return "person"
        }
    }
}

struct StreetAssistBottomTabBar: View {
    @Binding var selected: StreetAssistTab

    var body: some View {
        HStack {
            ForEach(StreetAssistTab.allCases, id: \.self) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selected == tab ? AppTheme.primaryBlue : AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(AppTheme.cardBackground)
        .overlay(
            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1),
            alignment: .top
        )
    }
}

#Preview {
    StreetAssistBottomTabBar(selected: .constant(.home))
}
