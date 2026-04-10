import MapKit
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selectedScope: HelpScope = .helpZoneOnly
    @State private var isShowingHelpSheet = false
    @State private var pendingCategorySelection: HelpCategory?
    @State private var isShowingTechnicalRepair = false
    @State private var isShowingPhysicalLogistics = false
    @State private var isShowingRoadsideEmergencies = false
    @State private var isShowingErrandsAndSocial = false

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(title: "StreetAssist")

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    helperToggleCard
                    scopeSelector
                    needAHandCard
                    mapPreview
                    statsRow
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

        }
        .background(AppTheme.screenBackground)
        .sheet(isPresented: $isShowingHelpSheet, onDismiss: {
            switch pendingCategorySelection {
            case .technicalAndRepair:
                isShowingTechnicalRepair = true
            case .physicalAndLogistics:
                isShowingPhysicalLogistics = true
            case .roadsideAndEmergency:
                isShowingRoadsideEmergencies = true
            case .errandsAndSocial:
                isShowingErrandsAndSocial = true
            default:
                break
            }
            pendingCategorySelection = nil
        }) {
            if #available(iOS 16.4, *) {
                HelpRequestSheetView(isPresented: $isShowingHelpSheet) { category in
                    pendingCategorySelection = category
                    isShowingHelpSheet = false
                }
                    .presentationDetents([.fraction(0.78)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            } else if #available(iOS 16.0, *) {
                HelpRequestSheetView(isPresented: $isShowingHelpSheet) { category in
                    pendingCategorySelection = category
                    isShowingHelpSheet = false
                }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            } else {
                HelpRequestSheetView(isPresented: $isShowingHelpSheet) { category in
                    pendingCategorySelection = category
                    isShowingHelpSheet = false
                }
            }
        }
        .navigationDestination(isPresented: $isShowingTechnicalRepair) {
            TechnicalRepairView()
        }
        .navigationDestination(isPresented: $isShowingPhysicalLogistics) {
            PhysicalLogisticsView()
        }
        .navigationDestination(isPresented: $isShowingRoadsideEmergencies) {
            RoadsideEmergenciesView()
        }
        .navigationDestination(isPresented: $isShowingErrandsAndSocial) {
            ErrandsAndSocialView()
        }
    }

    private var helperToggleCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("I'm a Helper")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Earn points by assisting others")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $session.isHelperEnabled)
                .labelsHidden()
                .tint(AppTheme.liveGreen)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }

    private var scopeSelector: some View {
        HStack(spacing: 12) {
            scopePill(title: "Help-Zone only", isSelected: selectedScope == .helpZoneOnly) {
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

    private var needAHandCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primaryBlueDark, AppTheme.primaryBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 10) {
                Text("Need a Hand?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("Connect with trusted\nhelpers nearby in\nseconds.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    isShowingHelpSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Request Help")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.primaryBlueDark)
                    .padding(.vertical, 14)
                    .frame(maxWidth: 210)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(20)
        }
        .frame(height: 250)
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
    }

    private var mapPreview: some View {
        ZStack(alignment: .bottomLeading) {
            Map(coordinateRegion: $region)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))

            helpersNearbyOverlay
                .padding(12)
        }
    }

    private var helpersNearbyOverlay: some View {
        HStack(spacing: 10) {
            avatarStack

            Text("12 Helpers Nearby")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer(minLength: 8)

            Circle()
                .fill(AppTheme.liveGreen)
                .frame(width: 8, height: 8)

            Text("Live")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 8)
    }

    private var avatarStack: some View {
        HStack(spacing: -10) {
            Circle()
                .fill(Color.orange.opacity(0.9))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "person.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                .overlay(Circle().stroke(Color.white, lineWidth: 2))

            Circle()
                .fill(Color.pink.opacity(0.9))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "person.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                .overlay(Circle().stroke(Color.white, lineWidth: 2))

            Circle()
                .fill(AppTheme.primaryBlue)
                .frame(width: 34, height: 28)
                .overlay(Text("+9").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white, lineWidth: 2))
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(title: "YOUR SCORE", value: "4.9", suffix: "/5.0")
            statCard(title: "IMPACT", value: "128", suffix: "Assists")
        }
    }

    private func statCard(title: String, value: String, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(title == "IMPACT" ? Color.orange : AppTheme.primaryBlue)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(suffix)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }
}

enum HelpScope {
    case helpZoneOnly
    case helpZoneAndGlobal
}

#Preview {
    HomeView()
        .environmentObject(AppSession())
}
