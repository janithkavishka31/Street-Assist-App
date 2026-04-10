import SwiftUI

struct ErrandsAndSocialView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isShowingNewRequest = false
    @State private var newRequestServiceTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(
                title: "Errands & Social",
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
            Image(systemName: "clock.fill")
                .font(.system(size: 12, weight: .bold))
            Text("ERRANDS & SOCIAL")
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
                .fill(Color.black.opacity(0.88))
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.10), Color.black.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            ZStack {
                Image(systemName: "cup.and.saucer.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 140)
                    .foregroundStyle(Color.white.opacity(0.18))

                Text("QUICK")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.12))
                    .offset(y: -66)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(x: 80, y: 10)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("MOST REQUESTED")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AppTheme.categoryOrange.opacity(0.90))
                        .clipShape(Capsule())

                    Text("Quick Coffee Run")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Need your caffeine fix but can't leave\nyour desk? We've got you covered.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    newRequestServiceTitle = "Quick Coffee Run"
                    isShowingNewRequest = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.primaryBlue)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
            .padding(20)
        }
        .frame(height: 210)
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
    }

    private var servicesList: some View {
        VStack(spacing: 14) {
            ServiceRowCard(
                icon: "stopwatch.fill",
                iconForeground: AppTheme.textSecondary,
                iconBackground: Color.black.opacity(0.06),
                title: "Queue Holding",
                subtitle: "We wait, you save time.",
                onTap: {
                    newRequestServiceTitle = "Queue Holding"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "cart.fill",
                iconForeground: AppTheme.categoryGreen,
                iconBackground: AppTheme.categoryGreenBackground,
                title: "Grocery Pick-up",
                subtitle: "Fresh items delivered fast.",
                onTap: {
                    newRequestServiceTitle = "Grocery Pick-up"
                    isShowingNewRequest = true
                }
            )

            ServiceRowCard(
                icon: "character.book.closed.fill",
                iconForeground: AppTheme.categoryOrange,
                iconBackground: AppTheme.categoryOrangeBackground,
                title: "Translation Help",
                subtitle: "Professional linguistic support",
                onTap: {
                    newRequestServiceTitle = "Translation Help"
                    isShowingNewRequest = true
                }
            )
        }
    }

    private var nearbyHelpers: some View {
        HStack(spacing: 12) {
            HelperCard(
                name: "Marcus T.",
                role: "Translator",
                distance: "450M AWAY",
                distanceColor: AppTheme.liveGreen
            )

            HelperCard(
                name: "Elena G.",
                role: "Translator",
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
        ErrandsAndSocialView()
    }
}
