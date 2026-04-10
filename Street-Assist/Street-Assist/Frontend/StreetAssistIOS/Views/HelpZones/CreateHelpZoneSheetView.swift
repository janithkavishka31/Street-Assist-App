import PhotosUI
import SwiftUI

struct CreateHelpZoneSheetView: View {
    @Binding var isPresented: Bool

    @State private var zoneName: String = ""
    @State private var organizationName: String = ""

    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedIDImage: UIImage?

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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Verification ensures your Help-Zone is\nmanaged by a legitimate institution to maintain\ncommunity safety.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        fieldBlock(
                            title: "Zone Name",
                            placeholder: "e.g., Office Plaza",
                            text: $zoneName
                        )

                        fieldBlock(
                            title: "Organization Name",
                            placeholder: "Official business or institution name",
                            text: $organizationName
                        )

                        uploadBlock

                        verificationTimeline

                        submitButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
            .padding(.bottom, 10)
        }
        .onChange(of: pickerItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedIDImage = image
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Create a Help-Zone")
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

    private func fieldBlock(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.04))

                TextField("", text: text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.gray.opacity(0.35))
                        .padding(.horizontal, 14)
                }
            }
            .frame(height: 54)
        }
    }

    private var uploadBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upload Business/Institutional ID")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                        .fill(Color.white.opacity(0.0))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                                .stroke(
                                    AppTheme.textSecondary.opacity(0.25),
                                    style: StrokeStyle(lineWidth: 2, dash: [7, 7])
                                )
                        )

                    VStack(spacing: 12) {
                        Circle()
                            .fill(AppTheme.categoryBlueBackground)
                            .frame(width: 54, height: 54)
                            .overlay(
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryBlue)
                            )

                        Text("Choose file or drag here")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("PDF, JPG or PNG (Max 10MB)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .frame(height: 170)
            }
            .buttonStyle(.plain)

            if let selectedIDImage {
                HStack(spacing: 12) {
                    Image(uiImage: selectedIDImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 54, height: 54)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("ID selected")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Spacer()

                    Button {
                        self.selectedIDImage = nil
                        self.pickerItem = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.subtleButtonBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: AppTheme.shadow, radius: 12, x: 0, y: 8)
            }
        }
    }

    private var verificationTimeline: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.20))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.orange.opacity(0.9))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("Verification Timeline")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.orange.opacity(0.9))

                Text("Verification usually takes 24–48 hours. Our\nteam will review your submission and notify\nyou once approved.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var submitButton: some View {
        Button {
            // Save/upload later
            isPresented = false
        } label: {
            Text("Submit Verification")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(AppTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
        .padding(.top, 6)
    }
}

#Preview {
    CreateHelpZoneSheetView(isPresented: .constant(true))
}
