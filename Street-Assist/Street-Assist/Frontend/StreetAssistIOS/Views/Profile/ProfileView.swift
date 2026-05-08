import SwiftUI
import AVFoundation
import AudioToolbox

struct ProfileView: View {
    private static let speechSynthesizer = AVSpeechSynthesizer()

    @EnvironmentObject private var session: AppSession

    @State private var profile: HelpRequestService.UserProfileSummary?
    @State private var allSkills: [Skill] = []
    @State private var isLoadingProfile = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var hasLoadedForm = false
    @State private var hasFinishedInitialLoad = false

    @State private var fullName: String = ""
    @State private var phone: String = ""
    @State private var quickBio: String = ""
    @State private var isHelperEnabled: Bool = false
    @State private var defaultScope: RequestScope = .helpZoneAndGlobal
    @State private var isScreenReaderEnabled: Bool = false
    @State private var isSoundEffectsEnabled: Bool = true
    @State private var isDynamicTextEnabled: Bool = true
    @State private var selectedSkillIDs: Set<Int> = []

    private let authService = SupabaseAuthService()

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(title: "Profile", leadingStyle: .avatar, trailingStyle: .none)

            ScrollView {
                VStack(spacing: 14) {
                    if isLoadingProfile {
                        ProgressView("Loading profile...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                    } else if let profile {
                        profileHeaderCard(profile)
                        statsRow(profile)
                        editProfileCard
                        settingsCard
                        skillsEditorCard
                        saveButton
                    }

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

                    if let successMessage {
                        Text(successMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.liveGreen)
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
        .task {
            await loadProfile()
        }
        .onChange(of: isHelperEnabled) { newValue in
            session.isHelperEnabled = newValue
        }
        .onChange(of: isScreenReaderEnabled) { newValue in
            guard hasFinishedInitialLoad else { return }
            if newValue {
                speakIfEnabled("Screen reader enabled")
            } else if isSoundEffectsEnabled {
                playTapSound()
            }
        }
        .onChange(of: isSoundEffectsEnabled) { newValue in
            guard hasFinishedInitialLoad else { return }
            if newValue {
                playTapSound()
            }
            speakIfEnabled(newValue ? "Sound effects enabled" : "Sound effects disabled")
        }
        .onChange(of: isDynamicTextEnabled) { _ in
            guard hasFinishedInitialLoad else { return }
            if isSoundEffectsEnabled {
                playTapSound()
            }
            speakIfEnabled(isDynamicTextEnabled ? "Dynamic text enabled" : "Dynamic text disabled")
        }
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

    @MainActor
    private func loadProfile() async {
        isLoadingProfile = true
        defer { isLoadingProfile = false }
        do {
            async let profileTask = HelpRequestService.shared.fetchCurrentUserProfileSummary()
            async let skillsTask = HelpRequestService.shared.fetchAllSkills()
            let (summary, skills) = try await (profileTask, skillsTask)
            profile = summary
            allSkills = skills
            if !hasLoadedForm {
                applyProfileToForm(summary)
                hasLoadedForm = true
                hasFinishedInitialLoad = true
            }
        } catch {
            errorMessage = "Unable to load profile: \(error.localizedDescription)"
        }
    }

    private func profileHeaderCard(_ profile: HelpRequestService.UserProfileSummary) -> some View {
        HStack(spacing: 14) {
            Circle()
                .fill(AppTheme.categoryBlueBackground)
                .frame(width: 64, height: 64)
                .overlay(
                    Text(initials(for: profile.user.fullName))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlue)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.user.fullName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                if let phone = profile.user.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                } else if let email = profile.user.email, !email.isEmpty {
                    Text(email)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Text(profile.user.quickBio?.isEmpty == false ? profile.user.quickBio! : "No bio yet. Add one in account setup.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
    }

    private func statsRow(_ profile: HelpRequestService.UserProfileSummary) -> some View {
        HStack(spacing: 12) {
            statCard(title: "POINTS", value: "\(profile.totalPoints)")
            statCard(title: "WEEKLY", value: "\(profile.weeklyAssists)")
            statCard(title: "STREAK", value: "\(profile.currentStreakDays)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.primaryBlue)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }

    private var editProfileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Profile")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            fieldLabel("Full Name")
            TextField("Enter full name", text: $fullName)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(AppTheme.sheetBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            fieldLabel("Phone")
            TextField("Enter phone", text: $phone)
                .keyboardType(.phonePad)
                .padding(12)
                .background(AppTheme.sheetBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            fieldLabel("Quick Bio")
            TextEditor(text: $quickBio)
                .frame(height: 90)
                .padding(8)
                .background(AppTheme.sheetBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack {
                Text("Helper Mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Toggle("", isOn: $isHelperEnabled)
                    .labelsHidden()
                    .tint(AppTheme.liveGreen)
            }

            fieldLabel("Default Scope")
            Picker("Default Scope", selection: $defaultScope) {
                Text("Zone Only").tag(RequestScope.helpZoneOnly)
                Text("Zone + Global").tag(RequestScope.helpZoneAndGlobal)
            }
            .pickerStyle(.segmented)

            Divider()
                .padding(.vertical, 4)

            Text("Accessibility")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack {
                Text("Screen Reader")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Toggle("", isOn: $isScreenReaderEnabled)
                    .labelsHidden()
                    .tint(AppTheme.primaryBlue)
            }

            HStack {
                Text("Sound Effects")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Toggle("", isOn: $isSoundEffectsEnabled)
                    .labelsHidden()
                    .tint(AppTheme.primaryBlue)
            }

            HStack {
                Text("Dynamic Text")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Toggle("", isOn: $isDynamicTextEnabled)
                    .labelsHidden()
                    .tint(AppTheme.primaryBlue)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
    }

    private var skillsEditorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manage Skills")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            if allSkills.isEmpty {
                Text("No skills available.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                let skillRows = chunk(allSkills, size: 2)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(skillRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 8) {
                            ForEach(row, id: \.id) { skill in
                                Button {
                                    toggleSkill(skill.id)
                                } label: {
                                    Text(skill.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(selectedSkillIDs.contains(skill.id) ? .white : AppTheme.primaryBlue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedSkillIDs.contains(skill.id) ? AppTheme.primaryBlue : AppTheme.categoryBlueBackground)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
    }

    private var saveButton: some View {
        Button {
            Task { await saveProfileChanges() }
        } label: {
            HStack {
                Spacer()
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save Profile Changes")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .background(AppTheme.primaryBlue)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isSubmitting)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(AppTheme.textSecondary)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "U" : letters.uppercased()
    }

    private func applyProfileToForm(_ summary: HelpRequestService.UserProfileSummary) {
        fullName = summary.user.fullName
        phone = summary.user.phone ?? ""
        quickBio = summary.user.quickBio ?? ""
        isHelperEnabled = summary.settings?.isHelperEnabled ?? false
        defaultScope = summary.settings?.defaultScope ?? .helpZoneAndGlobal
        isScreenReaderEnabled = summary.settings?.isScreenReaderEnabled ?? false
        isSoundEffectsEnabled = summary.settings?.isSoundEffectsEnabled ?? true
        isDynamicTextEnabled = summary.settings?.isDynamicTextEnabled ?? true
        selectedSkillIDs = summary.selectedSkillIDs
    }

    private func toggleSkill(_ skillID: Int) {
        if selectedSkillIDs.contains(skillID) {
            selectedSkillIDs.remove(skillID)
        } else {
            selectedSkillIDs.insert(skillID)
        }
    }

    @MainActor
    private func saveProfileChanges() async {
        guard !isSubmitting else { return }
        errorMessage = nil
        successMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let payload = HelpRequestService.UserProfileUpdatePayload(
                fullName: fullName,
                phone: phone,
                quickBio: quickBio,
                isHelperEnabled: isHelperEnabled,
                defaultScope: defaultScope,
                isScreenReaderEnabled: isScreenReaderEnabled,
                isSoundEffectsEnabled: isSoundEffectsEnabled,
                isDynamicTextEnabled: isDynamicTextEnabled,
                selectedSkillIDs: selectedSkillIDs
            )
            try await HelpRequestService.shared.updateCurrentUserProfile(payload: payload)
            profile = try await HelpRequestService.shared.fetchCurrentUserProfileSummary()
            if let profile {
                applyProfileToForm(profile)
            }
            successMessage = "Profile updated successfully."
            if isSoundEffectsEnabled {
                playTapSound()
            }
            speakIfEnabled("Profile updated successfully")
        } catch {
            errorMessage = "Unable to save profile: \(error.localizedDescription)"
        }
    }

    private func speakIfEnabled(_ text: String) {
        guard isScreenReaderEnabled else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        Self.speechSynthesizer.speak(utterance)
    }

    private func playTapSound() {
        AudioServicesPlaySystemSound(1104)
    }
}

private struct FlexibleTagWrap: View {
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(chunk(tags, size: 2), id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.primaryBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppTheme.categoryBlueBackground)
                            .clipShape(Capsule())
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chunk(_ array: [String], size: Int) -> [[String]] {
        stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }
}

private func chunk<T>(_ array: [T], size: Int) -> [[T]] {
    stride(from: 0, to: array.count, by: size).map {
        Array(array[$0..<min($0 + size, array.count)])
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppSession())
}
