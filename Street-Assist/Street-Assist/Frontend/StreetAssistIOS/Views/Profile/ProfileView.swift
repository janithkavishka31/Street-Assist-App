import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: AppSession

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let authService = SupabaseAuthService()

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(title: "Profile", leadingStyle: .avatar, trailingStyle: .none)

            ScrollView {
                VStack(spacing: 14) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
                    }

                    Button {
                        Task { await handleLogout() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Text(isSubmitting ? "Logging out…" : "Log out")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)

                            Spacer()

                            if isSubmitting {
                                ProgressView()
                                    .tint(AppTheme.textSecondary)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .background(AppTheme.screenBackground)
    }

    @MainActor
    private func handleLogout() async {
        guard isSubmitting == false else { return }

        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await authService.signOut()
            session.isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppSession())
}
