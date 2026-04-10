import SwiftUI

struct IncomingRequestsView: View {
    enum Scope {
        case helpZoneOnly
        case helpZoneAndGlobal
    }

    @EnvironmentObject private var session: AppSession

    @State private var isShowingHelperModeSheet = false
    @State private var selectedScope: Scope = .helpZoneAndGlobal

    private let placeholderRequests: [IncomingRequest] = [
        .init(
            category: "Roadside",
            categoryStyle: .gray,
            timeAgo: "20 mins ago",
            distance: "450M AWAY",
            title: "Flat Tire Assistance",
            subtitle: "Sedan needs help changing to a spare near..."
        ),
        .init(
            category: "Technical",
            categoryStyle: .orange,
            timeAgo: "5 mins ago",
            distance: nil,
            zone: "Zone: Central Campus",
            zoneStyle: .green,
            title: "Bike Chain Repair",
            subtitle: "Chain snapped while commuting. Have tool..."
        ),
        .init(
            category: "Physical",
            categoryStyle: .gray,
            timeAgo: "15 mins ago",
            distance: nil,
            title: "Heavy Lifting",
            subtitle: "Need help moving a small dresser from the..."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(title: "StreetAssist")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    helperModeCard
                    scopeSelector
                    pointsCard
                    smallStatsRow

                    if session.isHelperEnabled {
                        incomingRequestsSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .background(AppTheme.screenBackground)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !session.isHelperEnabled {
                isShowingHelperModeSheet = true
            }
        }
        .onChange(of: session.isHelperEnabled) { enabled in
            if enabled {
                isShowingHelperModeSheet = false
            } else {
                isShowingHelperModeSheet = true
            }
        }
        .sheet(isPresented: $isShowingHelperModeSheet) {
            if #available(iOS 16.4, *) {
                HelperModeRequiredSheetView(
                    isPresented: $isShowingHelperModeSheet,
                    onTurnOnNow: { session.isHelperEnabled = true }
                )
                .presentationDetents([.fraction(0.42)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            } else if #available(iOS 16.0, *) {
                HelperModeRequiredSheetView(
                    isPresented: $isShowingHelperModeSheet,
                    onTurnOnNow: { session.isHelperEnabled = true }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            } else {
                HelperModeRequiredSheetView(
                    isPresented: $isShowingHelperModeSheet,
                    onTurnOnNow: { session.isHelperEnabled = true }
                )
            }
        }
    }

    private var helperModeCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Helper Mode")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(session.isHelperEnabled ? "Currently ON" : "Currently OFF")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(session.isHelperEnabled ? AppTheme.primaryBlue : AppTheme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $session.isHelperEnabled)
                .labelsHidden()
                .tint(AppTheme.primaryBlue)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }

    private var scopeSelector: some View {
        HStack(spacing: 12) {
            scopePill(title: "Help-Zone Only", isSelected: selectedScope == .helpZoneOnly) {
                selectedScope = .helpZoneOnly
            }
            scopePill(title: "Help-Zone + Global", isSelected: selectedScope == .helpZoneAndGlobal) {
                selectedScope = .helpZoneAndGlobal
            }
        }
    }

    private func scopePill(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? AppTheme.primaryBlue : AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: isSelected ? 0 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Points")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("1,450")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)

                Text("+120 today")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.liveGreen)

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }

    private var smallStatsRow: some View {
        HStack(spacing: 12) {
            smallStatCard(title: "Weekly Assists", value: "12")
            smallStatCard(title: "Current Streak", value: "6 Days", valueColor: AppTheme.categoryOrange, trailingIcon: "flame.fill")
        }
    }

    private func smallStatCard(
        title: String,
        value: String,
        valueColor: Color = AppTheme.textPrimary,
        trailingIcon: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(valueColor)

                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(valueColor)
                        .offset(y: -1)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }

    private var incomingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("Nearby Help Requests")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Text("3 live nearby")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)
            }
            .padding(.top, 6)

            VStack(spacing: 14) {
                ForEach(placeholderRequests) { request in
                    IncomingRequestCardView(request: request)
                }
            }
        }
    }
}

private struct IncomingRequest: Identifiable {
    enum TagStyle {
        case gray
        case orange
        case green

        var background: Color {
            switch self {
            case .gray:
                return Color.black.opacity(0.07)
            case .orange:
                return AppTheme.categoryOrangeBackground
            case .green:
                return AppTheme.categoryGreenBackground
            }
        }

        var foreground: Color {
            switch self {
            case .gray:
                return AppTheme.textSecondary
            case .orange:
                return AppTheme.categoryOrange
            case .green:
                return AppTheme.categoryGreen
            }
        }
    }

    let id = UUID()

    let category: String
    let categoryStyle: TagStyle
    let timeAgo: String
    let distance: String?

    var zone: String? = nil
    var zoneStyle: TagStyle? = nil

    let title: String
    let subtitle: String
}

private struct IncomingRequestCardView: View {
    let request: IncomingRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TagPill(text: request.category, style: request.categoryStyle)

                if let zone = request.zone, let zoneStyle = request.zoneStyle {
                    TagPill(text: zone, style: zoneStyle)
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .bold))
                    Text(request.timeAgo)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(AppTheme.textSecondary)

                Spacer(minLength: 0)

                if let distance = request.distance {
                    Text(distance)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.70))
                        .clipShape(Capsule())
                }
            }

            Text(request.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(request.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                // Accept flow will be wired later
            } label: {
                Text("Accept")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
    }
}

private struct TagPill: View {
    let text: String
    let style: IncomingRequest.TagStyle

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(style.background)
            .clipShape(Capsule())
    }
}

#Preview {
    IncomingRequestsView()
        .environmentObject(AppSession())
}
