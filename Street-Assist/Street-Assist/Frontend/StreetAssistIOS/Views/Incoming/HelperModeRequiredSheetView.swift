import SwiftUI

struct HelperModeRequiredSheetView: View {
    @Binding var isPresented: Bool
    var onTurnOnNow: () -> Void = {}

    var body: some View {
        ZStack {
            AppTheme.sheetBackground
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Capsule()
                    .fill(AppTheme.border)
                    .frame(width: 44, height: 5)
                    .padding(.top, 8)

                HStack {
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

                VStack(alignment: .leading, spacing: 16) {
                    Text("Please turn on the Helper mode to\nrecieve incoming requests")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        onTurnOnNow()
                        isPresented = false
                    } label: {
                        Text("Turn On Now")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 220)
                            .padding(.vertical, 14)
                            .background(AppTheme.primaryBlue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    HelperModeRequiredSheetView(isPresented: .constant(true))
}
