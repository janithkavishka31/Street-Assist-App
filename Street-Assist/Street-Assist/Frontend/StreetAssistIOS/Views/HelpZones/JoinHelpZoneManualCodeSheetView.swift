import SwiftUI

struct JoinHelpZoneManualCodeSheetView: View {
    @Binding var isPresented: Bool
    var onJoined: () -> Void = {}

    @State private var code: String = ""

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

                VStack(alignment: .leading, spacing: 18) {
                    Text("Enter your Help-Zone code to join.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)

                    field

                    submitButton

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Join a Help-Zone")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

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
        .padding(.horizontal, 18)
        .padding(.top, 6)
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Help-Zone Code")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.04))

                TextField("", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                if code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("e.g., CAMPUS-24X8")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gray.opacity(0.35))
                        .padding(.horizontal, 14)
                }
            }
            .frame(height: 54)
        }
    }

    private var submitButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                submitJoin()
            } label: {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Join Zone")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AppTheme.primaryBlue)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .buttonStyle(.plain)
            .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
            .padding(.top, 8)
            .disabled(isSubmitting || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .alert(isPresented: $showError) {
                Alert(title: Text("Error"), message: Text(errorMessage ?? "Unable to join."), dismissButton: .default(Text("OK")))
            }

            if showSuccess {
                Text("Successfully joined zone.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.categoryGreen)
                    .transition(.opacity)
            }
        }
    }

    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage: String?

    private func submitJoin() {
        isSubmitting = true
        Task {
            do {
                _ = try await HelpZoneService.shared.joinZone(joinCode: code.trimmingCharacters(in: .whitespacesAndNewlines))
                DispatchQueue.main.async {
                    isSubmitting = false
                    showSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                        onJoined()
                        isPresented = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    JoinHelpZoneManualCodeSheetView(isPresented: .constant(true))
}
