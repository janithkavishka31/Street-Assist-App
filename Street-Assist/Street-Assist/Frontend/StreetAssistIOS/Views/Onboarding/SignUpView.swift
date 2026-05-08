import SwiftUI

struct SignUpView: View {
    enum Mode {
        case needHelp
        case wantToHelp
    }

    enum Skill: Hashable, CaseIterable {
        case technical
        case physical
        case roadside
        case errands

        var dbKey: String {
            switch self {
            case .technical: return "technical"
            case .physical: return "physical"
            case .roadside: return "roadside"
            case .errands: return "errands"
            }
        }

        var title: String {
            switch self {
            case .technical: return "Technical"
            case .physical: return "Physical"
            case .roadside: return "Roadside"
            case .errands: return "Errands"
            }
        }

        var subtitle: String {
            switch self {
            case .technical: return "Repairs & Gadgets"
            case .physical: return "Lifting & Labor"
            case .roadside: return "Jumpstarts & Flats"
            case .errands: return "Pickup & Delivery"
            }
        }

        var icon: String {
            switch self {
            case .technical: return "wrench.and.screwdriver.fill"
            case .physical: return "dumbbell.fill"
            case .roadside: return "wrench.fill"
            case .errands: return "basket.fill"
            }
        }
    }

    var onCreateAccount: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .needHelp

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible = false

    @State private var agreedToTerms = false

    @State private var quickBio: String = ""
    @State private var selectedSkills: Set<Skill> = []

    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private let authService = SupabaseAuthService()

    var body: some View {
        ZStack {
            AppTheme.screenBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Join the community")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.top, 18)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.85))
                        } else if let infoMessage {
                            Text(infoMessage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        modeToggle

                        Group {
                            switch mode {
                            case .needHelp:
                                needHelpForm
                            case .wantToHelp:
                                wantToHelpForm
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryBlue)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    // wired later
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }

            Text("StreetAssist")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.primaryBlue)
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            togglePill(title: "I need help", isSelected: mode == .needHelp) {
                mode = .needHelp
            }
            togglePill(title: "I want to help", isSelected: mode == .wantToHelp, isEnabled: isNeedHelpComplete) {
                mode = .wantToHelp
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func togglePill(title: String, isSelected: Bool, isEnabled: Bool = true, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }

    private var isNeedHelpComplete: Bool {
        let nameOk = !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let emailOk = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let phoneOk = !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordOk = !password.isEmpty
        return nameOk && emailOk && phoneOk && passwordOk && agreedToTerms
    }

    private var needHelpForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            labeledField(title: "FULL NAME", icon: "person.fill", placeholder: "John Doe", text: $fullName)
            labeledField(title: "EMAIL ADDRESS", icon: "envelope.fill", placeholder: "john@example.com", text: $email)
            labeledField(title: "PHONE NUMBER", icon: "phone.fill", placeholder: "+1 (555) 000-0000", text: $phone)

            VStack(alignment: .leading, spacing: 10) {
                Text("PASSWORD")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .tracking(1.2)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.04))

                    HStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(width: 22)

                        ZStack(alignment: .leading) {
                            if password.isEmpty {
                                Text("••••••••")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.gray.opacity(0.55))
                            }

                            Group {
                                if isPasswordVisible {
                                    TextField("", text: $password)
                                } else {
                                    SecureField("", text: $password)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                        }

                        Spacer(minLength: 0)

                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .frame(height: 58)
            }

            HStack(alignment: .top, spacing: 12) {
                Button {
                    agreedToTerms.toggle()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 2)
                            .frame(width: 26, height: 26)

                        if agreedToTerms {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.primaryBlue)
                        }
                    }
                }
                .buttonStyle(.plain)

                Text("By creating an account, you agree to our\n")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                + Text("Terms of service")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)
                + Text(" and ")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                + Text("Privacy Policy")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)
                + Text(".")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.top, 6)

            Button {
                guard isNeedHelpComplete else {
                    errorMessage = "Please complete all fields and agree to the terms to continue."
                    infoMessage = nil
                    return
                }

                errorMessage = nil
                infoMessage = nil
                mode = .wantToHelp
            } label: {
                HStack {
                    Spacer()

                    Text("Next Step")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 18)
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
            .padding(.top, 8)

            HStack(spacing: 8) {
                Text("Already have an account?")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Button {
                    dismiss()
                } label: {
                    Text("Login")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlue)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
    }

    private var wantToHelpForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Quick Bio")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .fill(Color.black.opacity(0.04))

                TextEditor(text: $quickBio)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(height: 92)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)

                if quickBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Tell others how you can help...")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.gray.opacity(0.55))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                }
            }

            Text("Select your primary skills")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 6)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(Skill.allCases, id: \.self) { skill in
                    SkillTile(
                        title: skill.title,
                        subtitle: skill.subtitle,
                        icon: skill.icon,
                        isSelected: selectedSkills.contains(skill)
                    ) {
                        if selectedSkills.contains(skill) {
                            selectedSkills.remove(skill)
                        } else {
                            selectedSkills.insert(skill)
                        }
                    }
                }
            }

            Button {
                Task { await submitSignUp(includeHelperInfo: true) }
            } label: {
                Text("Complete & Create Account")
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
            .padding(.top, 6)
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.7 : 1)

            Button {
                Task { await submitSignUp(includeHelperInfo: false) }
            } label: {
                Text("Skip & Create Account")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.7 : 1)
        }
    }

    @MainActor
    private func submitSignUp(includeHelperInfo: Bool) async {
        guard !isSubmitting else { return }

        guard isNeedHelpComplete else {
            errorMessage = "Please complete the required signup details first."
            infoMessage = nil
            mode = .needHelp
            return
        }

        isSubmitting = true
        errorMessage = nil
        infoMessage = nil

        let bio = includeHelperInfo ? quickBio : nil
        let skills = includeHelperInfo ? selectedSkills.map { $0.dbKey } : nil

        do {
            let didCreateSession = try await authService.signUpEmail(
                fullName: fullName,
                email: email,
                phone: phone,
                password: password,
                agreedToTerms: agreedToTerms,
                quickBio: bio,
                skills: skills
            )

            if didCreateSession {
                onCreateAccount()
            } else {
                infoMessage = "Account created. Please confirm your email, then login."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }

    private func labeledField(title: String, icon: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .tracking(1.2)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.04))

                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 22)

                    ZStack(alignment: .leading) {
                        if text.wrappedValue.isEmpty {
                            Text(placeholder)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.gray.opacity(0.55))
                        }

                        TextField("", text: text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.textPrimary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .frame(height: 58)
        }
    }
}

private struct SkillTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.20) : Color.black.opacity(0.06))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isSelected ? .white : AppTheme.primaryBlue)
                    )

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : AppTheme.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(isSelected ? AppTheme.primaryBlue : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .toolbar(.hidden, for: .navigationBar)
    }
}
