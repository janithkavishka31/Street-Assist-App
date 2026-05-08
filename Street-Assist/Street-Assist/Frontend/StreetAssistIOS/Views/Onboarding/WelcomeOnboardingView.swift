import SwiftUI

struct WelcomeOnboardingView: View {
    var onGetStarted: () -> Void = {}

    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                heroImage
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 18) {
                    Text("Welcome to\nStreetAssist.")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Experience safety redefined through\ncollective vigilance and immediate\nneighborhood support.")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineSpacing(3)

                    pageDots
                        .padding(.top, 12)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                getStartedBar
            }
        }
    }

    private var heroImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color.black.opacity(0.06))

            Image("OnboardingHero")
                .resizable()
                .scaledToFill()
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        .padding(.horizontal, 18)
    }

    private var pageDots: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(AppTheme.primaryBlue)
                .frame(width: 44, height: 6)

            Circle()
                .fill(Color.black.opacity(0.14))
                .frame(width: 8, height: 8)

            Circle()
                .fill(Color.black.opacity(0.14))
                .frame(width: 8, height: 8)

            Spacer(minLength: 0)
        }
    }

    private var getStartedBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 1)

            Button {
                onGetStarted()
            } label: {
                Text("Get Started")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.primaryBlueDark, AppTheme.primaryBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(AppTheme.screenBackground)
        }
    }
}

#Preview {
    WelcomeOnboardingView()
}
