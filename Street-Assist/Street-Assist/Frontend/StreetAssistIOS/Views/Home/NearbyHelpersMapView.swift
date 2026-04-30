import CoreLocation
import MapKit
import SwiftUI

struct NearbyHelpersMapView: View {
    @Environment(\.dismiss) private var dismiss

    let helperCoordinate: CLLocationCoordinate2D
    @State private var nearbyHelpers: [HelperLocation] = []
    @State private var isLoading = false
    @State private var mapRegion: MKCoordinateRegion

    private let nearbyThresholdMeters: CLLocationDistance = 5000

    init(helperCoordinate: CLLocationCoordinate2D) {
        self.helperCoordinate = helperCoordinate
        _mapRegion = State(initialValue: MKCoordinateRegion(
            center: helperCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        ))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(coordinateRegion: $mapRegion, annotationItems: nearbyHelpers) { helper in
                MapAnnotation(coordinate: helper.coordinate) {
                    VStack(spacing: 0) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.primaryBlue)
                            .background(Circle().fill(Color.white).frame(width: 40, height: 40))

                        Image(systemName: "triangle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(AppTheme.primaryBlue)
                            .offset(y: -4)
                    }
                }
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("\(nearbyHelpers.count) Helpers")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                }
                .padding(16)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.horizontal, 16)
                }

                Spacer()
            }
        }
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            Task { await loadNearbyHelpers() }
        }
    }

    @MainActor
    private func loadNearbyHelpers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            nearbyHelpers = try await HelpRequestService.shared.fetchNearbyHelpers(
                latitude: helperCoordinate.latitude,
                longitude: helperCoordinate.longitude,
                radiusMeters: nearbyThresholdMeters
            )
        } catch {
            print("Error loading nearby helpers: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NearbyHelpersMapView(
        helperCoordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783)
    )
}
