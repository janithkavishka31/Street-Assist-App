import SwiftUI

struct PhysicalLogisticsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingNewRequest = false
    @State private var newRequestServiceTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(
                title: "Physical & Logistic",
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
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 12, weight: .bold))
            Text("PHYSICAL & LOGISTICS")
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

            Image(systemName: "truck.box.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.black.opacity(0.12))
                .frame(width: 210, height: 140)
                .offset(x: 140, y: 14)

            VStack(alignment: .leading, spacing: 10) {
                Text("MOST REQUESTED")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())

                Text("Quick\nMove\nSupport")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(1)

                Button {
                    newRequestServiceTitle = "Quick Move Support"
                    isShowingNewRequest = true
                } label: {
                    Text("Request Now")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlueDark)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(20)
        }
        .frame(height: 200)
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
    }

    private var servicesList: some View {
        VStack(spacing: 14) {
            ServiceRowCard(
                icon: "suitcase.rolling.fill",
                iconForeground: AppTheme.primaryBlue,
                iconBackground: AppTheme.categoryBlueBackground,
                title: "Luggage Move",
                subtitle: "Fast transport for bags & suitcases",
                onTap: {
                    newRequestServiceTitle = "Luggage Move"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "car.fill",
                iconForeground: AppTheme.categoryOrange,
                iconBackground: AppTheme.categoryOrangeBackground,
                title: "Vehicle Push",
                subtitle: "On-site assist for stalled cars",
                onTap: {
                    newRequestServiceTitle = "Vehicle Push"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "dumbbell.fill",
                iconForeground: AppTheme.categoryGreen,
                iconBackground: AppTheme.categoryGreenBackground,
                title: "Heavy Lifting",
                subtitle: "Large items & equipment help",
                onTap: {
                    newRequestServiceTitle = "Heavy Lifting"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "wrench.and.screwdriver.fill",
                iconForeground: AppTheme.textSecondary,
                iconBackground: Color.black.opacity(0.06),
                title: "Furniture Assembly",
                subtitle: "Build & install flat-pack items",
                onTap: {
                    newRequestServiceTitle = "Furniture Assembly"
                    isShowingNewRequest = true
                }
            )
        }
    }

    private var nearbyHelpers: some View {
        HStack(spacing: 12) {
            HelperCard(
                name: "Marcus T.",
                role: "Luggage Mover",
                distance: "450M AWAY",
                distanceColor: AppTheme.liveGreen
            )

            HelperCard(
                name: "Elena G.",
                role: "Mover",
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
        PhysicalLogisticsView()
    }
}
