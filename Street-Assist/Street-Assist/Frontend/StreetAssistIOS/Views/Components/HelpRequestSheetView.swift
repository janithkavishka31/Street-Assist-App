import SwiftUI

enum HelpCategory {
    case technicalAndRepair
    case physicalAndLogistics
    case roadsideAndEmergency
    case errandsAndSocial
}

struct HelpRequestSheetView: View {
    @Binding var isPresented: Bool
    var onSelectCategory: (HelpCategory) -> Void = { _ in }

    var body: some View {
        ZStack {
            AppTheme.sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Capsule()
                    .fill(AppTheme.border)
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)

                header

                VStack(spacing: 14) {
                    HelpCategoryCard(
                        icon: "wrench.and.screwdriver.fill",
                        iconColor: AppTheme.categoryBlue,
                        iconBackground: AppTheme.categoryBlueBackground,
                        title: "Technical & Repair",
                        subtitle: "Tools, electronics, or fixes",
                        onTap: { onSelectCategory(.technicalAndRepair) }
                    )

                    HelpCategoryCard(
                        icon: "dumbbell.fill",
                        iconColor: AppTheme.categoryGreen,
                        iconBackground: AppTheme.categoryGreenBackground,
                        title: "Physical & Logistics",
                        subtitle: "Lifting, moving, or transport",
                        onTap: { onSelectCategory(.physicalAndLogistics) }
                    )

                    HelpCategoryCard(
                        icon: "fuelpump.fill",
                        iconColor: AppTheme.categoryOrange,
                        iconBackground: AppTheme.categoryOrangeBackground,
                        title: "Roadside & Emergency",
                        subtitle: "Jumpstarts, tires, or fuel",
                        onTap: { onSelectCategory(.roadsideAndEmergency) }
                    )

                    HelpCategoryCard(
                        icon: "clock.fill",
                        iconColor: AppTheme.categoryPurple,
                        iconBackground: AppTheme.categoryPurpleBackground,
                        title: "Errands & Social",
                        subtitle: "Deliveries, check-ins, or tasks",
                        onTap: { onSelectCategory(.errandsAndSocial) }
                    )
                }
                .padding(.top, 6)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("How can we help?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Select a category to find assistance.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.subtleButtonBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }
}

private struct HelpCategoryCard: View {
    let icon: String
    let iconColor: Color
    let iconBackground: Color
    let title: String
    let subtitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(iconColor)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.sheetCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HelpRequestSheetView(isPresented: .constant(true))
}
