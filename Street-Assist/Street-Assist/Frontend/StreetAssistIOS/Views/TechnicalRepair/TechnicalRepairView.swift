import SwiftUI

struct TechnicalRepairView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingNewRequest = false
    @State private var newRequestServiceTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(
                title: "Technical & Repair",
                leadingStyle: .back,
                trailingStyle: .avatar,
                onBackTap: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        categoryPill

                        Text("Find Local Support")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        featuredCard
                    }

                    servicesList

                    Text("Nearby Helpers")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.top, 6)

                    nearbyHelpers
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

        }
        .background(AppTheme.screenBackground)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $isShowingNewRequest) {
            NewRequestView(serviceTitle: newRequestServiceTitle)
        }
    }

    private var categoryPill: some View {
        HStack(spacing: 8) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 12, weight: .bold))
            Text("TECHNICAL & REPAIR")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(AppTheme.primaryBlue)
        .clipShape(Capsule())
    }

    private var featuredCard: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primaryBlueDark, AppTheme.primaryBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image("Repair Service")
                .resizable()
                .scaledToFill()
                .opacity(0.25)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("MOST REQUESTED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())

                Text("Emergency Tech Help")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text("On-site troubleshooting for\nnetwork and hardware issues")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))

                Button {
                    newRequestServiceTitle = "Emergency Tech Help"
                    isShowingNewRequest = true
                } label: {
                    Text("Book Now")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlueDark)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(20)
        }
        .frame(height: 170)
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
    }

    private var servicesList: some View {
        VStack(spacing: 14) {
            ServiceRowCard(
                icon: "bicycle",
                iconForeground: AppTheme.categoryGreen,
                iconBackground: AppTheme.categoryGreenBackground,
                title: "Bike Repair",
                subtitle: "Maintenance, flats & tuning",
                onTap: {
                    newRequestServiceTitle = "Bike Repair"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "car.fill",
                iconForeground: AppTheme.primaryBlue,
                iconBackground: AppTheme.categoryBlueBackground,
                title: "Car Repair",
                subtitle: "Diagnostics & minor fixes",
                onTap: {
                    newRequestServiceTitle = "Car Repair"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "bolt.fill",
                iconForeground: AppTheme.categoryOrange,
                iconBackground: AppTheme.categoryOrangeBackground,
                title: "Electrical",
                subtitle: "Wiring, lighting & outlets",
                onTap: {
                    newRequestServiceTitle = "Electrical"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "hammer.fill",
                iconForeground: AppTheme.textSecondary,
                iconBackground: Color.black.opacity(0.06),
                title: "Hardware",
                subtitle: "Locks, doors & installations",
                onTap: {
                    newRequestServiceTitle = "Hardware"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "display.2",
                iconForeground: .white,
                iconBackground: AppTheme.primaryBlue,
                title: "Digital/Tech Help",
                subtitle: "Setup, troubleshooting & data",
                iconUsesFilledCircle: true,
                onTap: {
                    newRequestServiceTitle = "Digital/Tech Help"
                    isShowingNewRequest = true
                }
            )
        }
    }

    private var nearbyHelpers: some View {
        HStack(spacing: 12) {
            HelperCard(
                name: "Marcus T.",
                role: "Bicycle Mechanic",
                distance: "450M AWAY",
                distanceColor: AppTheme.liveGreen
            )

            HelperCard(
                name: "Elena G.",
                role: "IT Consultant",
                distance: "1.2KM AWAY",
                distanceColor: AppTheme.primaryBlue
            )
        }
    }
}

private struct ServiceRowCard: View {
    let icon: String
    let iconForeground: Color
    let iconBackground: Color
    let title: String
    let subtitle: String
    var iconUsesFilledCircle: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                Group {
                    if iconUsesFilledCircle {
                        Circle()
                            .fill(iconBackground)
                            .frame(width: 48, height: 48)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(iconBackground)
                            .frame(width: 48, height: 48)
                    }
                }
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(iconForeground)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct HelperCard: View {
    let name: String
    let role: String
    let distance: String
    let distanceColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.black.opacity(0.06))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    )

                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer(minLength: 0)
            }

            Text(role)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(distance)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(distanceColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        TechnicalRepairView()
    }
}
