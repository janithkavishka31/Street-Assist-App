import SwiftUI

struct LoginView: View {
    var onLogin: () -> Void = {}
    var onSignUp: () -> Void = {}

    @State private var emailOrPhone: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    private let authService = SupabaseAuthService()

    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                header
                    .padding(.top, 10)

                Text("The Guardian's Pulse. Your safety, elevated\nthrough community intelligence.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Email or Phone")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    roundedField(
                        placeholder: "name@example.com",
                        text: $emailOrPhone,
                        isSecure: false
                    )
                }
                .padding(.top, 10)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Password")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Button {
                            // wired later
                        } label: {
                            Text("Forgot Password?")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.primaryBlue)
                        }
                        .buttonStyle(.plain)
                    }

                    roundedField(
                        placeholder: "••••••••",
                        text: $password,
                        isSecure: true
                    )
                }

                Button {
                    isSubmitting = true
                    errorMessage = nil

                    Task {
                        do {
                            try await authService.signInEmail(email: emailOrPhone, password: password)
                            await MainActor.run {
                                isSubmitting = false
                                onLogin()
                            }
                        } catch {
                            await MainActor.run {
                                isSubmitting = false
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    Text("Login")
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
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
                }
                .buttonStyle(.plain)
                    .disabled(isSubmitting)
                    .opacity(isSubmitting ? 0.7 : 1)
                .padding(.top, 8)

                connectWithDivider
                    .padding(.top, 12)

                VStack(spacing: 14) {
                    socialButton(title: "Continue with Apple", systemIcon: "apple.logo") {
                        // wired later
                    }

                    socialButton(title: "Continue with Google", googleStyle: true) {
                        // wired later
                    }
                }
                .padding(.top, 6)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Text("New here?")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    Button {
                        onSignUp()
                    } label: {
                        Text("Sign up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppTheme.primaryBlue)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
            }
            .padding(.horizontal, 22)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("StreetAssist")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.primaryBlue)
                    .frame(width: 56, height: 56)
                    .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)

                Image(systemName: "shield.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 6)
        }
    }

    private func roundedField(placeholder: String, text: Binding<String>, isSecure: Bool) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.04))

            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.gray.opacity(0.55))
                    .padding(.horizontal, 18)
            }

            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                        .textInputAutocapitalization(.never)
                }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(height: 56)
    }

    private var connectWithDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)

            Text("OR CONNECT WITH")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.gray.opacity(0.55))
                .tracking(1.2)

            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func socialButton(
        title: String,
        systemIcon: String? = nil,
        googleStyle: Bool = false,
        onTap: @escaping () -> Void
    ) -> some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                if googleStyle {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))

                        Text("G")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                } else if let systemIcon {
                    Image(systemName: systemIcon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 24, height: 24)
                }

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LoginView()
}
