import SwiftUI

enum StreetAssistNavBarLeadingStyle {
    case avatar
    case back
}

enum StreetAssistNavBarTrailingStyle {
    case bell
    case avatar
    case none
}

struct StreetAssistNavBar: View {
    let title: String
    var leadingStyle: StreetAssistNavBarLeadingStyle = .avatar
    var trailingStyle: StreetAssistNavBarTrailingStyle = .bell

    var onBackTap: (() -> Void)?
    var onNotificationsTap: (() -> Void)?
    var onAvatarTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            leadingView

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            trailingView
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.001))
    }

    @ViewBuilder
    private var leadingView: some View {
        switch leadingStyle {
        case .avatar:
            Button {
                onAvatarTap?()
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

        case .back:
            Button {
                onBackTap?()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailingStyle {
        case .bell:
            Button {
                onNotificationsTap?()
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppTheme.textPrimary)
            }
            .buttonStyle(.plain)

        case .avatar:
            Button {
                onAvatarTap?()
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

        case .none:
            EmptyView()
        }
    }
}

#Preview {
    StreetAssistNavBar(title: "StreetAssist")
        .background(AppTheme.screenBackground)
}
