import MapKit
import PhotosUI
import SwiftUI

struct NewRequestView: View {
    let category: HelpCategory

    @Environment(\.dismiss) private var dismiss

    @State private var descriptionText: String = ""

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )

    @State private var isSubmitting = false
    @State private var showSubmitError = false
    @State private var submitErrorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(
                title: "New Request",
                leadingStyle: .back,
                trailingStyle: .avatar,
                onBackTap: { dismiss() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Requesting for Help")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlue)
                        .padding(.top, 6)

                    problemDescriptionSection

                    addPhotoSection

                    repairLocationSection

                    submitSection
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

        }
        .background(AppTheme.screenBackground)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Unable to submit request", isPresented: $showSubmitError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(submitErrorMessage ?? "Please try again.")
        })
        .onChange(of: pickerItems) { newItems in
            Task { await loadPickedImages(from: newItems) }
        }
    }

    private var problemDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Problem Description")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                    .fill(AppTheme.cardBackground)

                TextEditor(text: $descriptionText)
                    .padding(12)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(height: 130)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(AppTheme.textPrimary)

                if descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Describe what's wrong with your \(serviceTitle.lowercased()) request...")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color.gray.opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 22)
                }
            }
        }
    }

    private var addPhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Photo")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 14) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    selectedPhotoThumb(image: image) {
                        selectedImages.remove(at: index)
                    }
                }

                PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                    addMoreTile
                }
            }
        }
    }

    private func selectedPhotoThumb(image: UIImage, onRemove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }

    private var addMoreTile: some View {
        VStack(spacing: 10) {
            ZStack {
                Image(systemName: "camera.fill")
                    .font(.system(size: 22, weight: .bold))
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .offset(x: 12, y: -10)
            }
            .foregroundStyle(AppTheme.textSecondary)

            Text("Add More")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(width: 120, height: 120)
        .background(Color.white.opacity(0.0))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    AppTheme.textSecondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                )
        )
    }

    private var repairLocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Repair Location")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button {
                    // Wire location fetch later
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Current Location")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.primaryBlue)
                }
                .buttonStyle(.plain)
            }

            ZStack(alignment: .bottom) {
                Map(coordinateRegion: $region, annotationItems: [PinnedLocation(coordinate: region.center)]) { pin in
                    MapMarker(coordinate: pin.coordinate, tint: AppTheme.primaryBlue)
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))

                selectedAddressCard
                    .padding(14)
            }
        }
    }

    private var selectedAddressCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.primaryBlue.opacity(0.10))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "map")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlue)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("SELECTED ADDRESS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)

                Text("2425 Mission St, San Francisco")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
    }

    private var submitSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await submitRequest() }
            } label: {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Submit Request")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)

                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.leading, 6)
                    }
                    Spacer()
                }
                .padding(.vertical, 18)
                .background(isSubmitting ? AppTheme.primaryBlue.opacity(0.6) : AppTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)

            Text("A technician will be assigned to your location within\n15 minutes of submission.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func submitRequest() async {
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            submitErrorMessage = "Please describe the issue before submitting."
            showSubmitError = true
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await HelpRequestService.shared.createRequest(
                category: category,
                description: trimmedDescription,
                latitude: region.center.latitude,
                longitude: region.center.longitude,
                scope: .helpZoneAndGlobal,
                zoneId: nil,
                photos: selectedImages
            )
            dismiss()
        } catch {
            submitErrorMessage = error.localizedDescription
            showSubmitError = true
            print("Error submitting request: \(error)")
        }
    }

    private var serviceTitle: String {
        switch category {
        case .technicalAndRepair:
            return "Technical & Repair"
        case .physicalAndLogistics:
            return "Physical & Logistics"
        case .roadsideAndEmergency:
            return "Roadside & Emergency"
        case .errandsAndSocial:
            return "Errands & Social"
        }
    }

    private func loadPickedImages(from items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                if !selectedImages.contains(where: { $0.pngData() == image.pngData() }) {
                    selectedImages.append(image)
                }
            }
        }
        pickerItems = []
    }
}

private struct PinnedLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    NavigationStack {
        NewRequestView(category: .technicalAndRepair)
            .toolbar(.hidden, for: .navigationBar)
    }
}
