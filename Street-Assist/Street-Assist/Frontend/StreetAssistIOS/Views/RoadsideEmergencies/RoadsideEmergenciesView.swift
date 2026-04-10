import SwiftUI

struct RoadsideEmergenciesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingNewRequest = false
    @State private var newRequestServiceTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(
                title: "Roadside & Emergencies",
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
            Image(systemName: "wrench.fill")
                .font(.system(size: 12, weight: .bold))
            Text("ROADSIDE & EMERGENCIES")
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
                .fill(Color.black.opacity(0.86))
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.black.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "bolt.car.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppTheme.categoryOrange.opacity(0.35))
                .frame(width: 220, height: 170)
                .offset(x: 150, y: 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("MOST REQUESTED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(AppTheme.categoryOrange.opacity(0.85))
                    .clipShape(Capsule())

                Text("Rapid Battery Jump")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Specialists available within 2 miles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))

                Button {
                    newRequestServiceTitle = "Rapid Battery Jump"
                    isShowingNewRequest = true
                } label: {
                    Text("Request Now")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 14)
                        .background(AppTheme.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .padding(20)
        }
        .frame(height: 180)
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
    }

    private var servicesList: some View {
        VStack(spacing: 14) {
            ServiceRowCard(
                icon: "bolt.batteryblock.fill",
                iconForeground: AppTheme.primaryBlue,
                iconBackground: AppTheme.categoryBlueBackground,
                title: "Battery Jump Start",
                subtitle: "Starts at $45",
                onTap: {
                    newRequestServiceTitle = "Battery Jump Start"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "wrench.and.screwdriver.fill",
                iconForeground: AppTheme.primaryBlue,
                iconBackground: AppTheme.categoryBlueBackground,
                title: "Flat Tire",
                subtitle: "Tools provided",
                onTap: {
                    newRequestServiceTitle = "Flat Tire"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "fuelpump.fill",
                iconForeground: AppTheme.primaryBlue,
                iconBackground: AppTheme.categoryBlueBackground,
                title: "Fuel Delivery",
                subtitle: "2 Gal Regular/Diesel",
                onTap: {
                    newRequestServiceTitle = "Fuel Delivery"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "lock.fill",
                iconForeground: AppTheme.primaryBlue,
                iconBackground: AppTheme.categoryBlueBackground,
                title: "Lockout",
                subtitle: "Non-destructive entry",
                onTap: {
                    newRequestServiceTitle = "Lockout"
                    isShowingNewRequest = true
                }
            )
        }
    }

    private var nearbyHelpers: some View {
        HStack(spacing: 12) {
            HelperCard(
                name: "Marcus T.",
                role: "Delivery Rider",
                distance: "450M AWAY",
                distanceColor: AppTheme.liveGreen
            )

            HelperCard(
                name: "Elena G.",
                role: "Mechanic",
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
    var onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 48, height: 48)
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
        RoadsideEmergenciesView()
    }
}
