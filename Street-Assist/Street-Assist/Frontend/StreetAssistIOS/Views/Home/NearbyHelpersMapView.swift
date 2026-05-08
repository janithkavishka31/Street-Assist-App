import CoreLocation
import MapKit
import SwiftUI

struct NearbyHelpersMapView: View {
    @Environment(\.dismiss) private var dismiss

    let helperCoordinate: CLLocationCoordinate2D
    @State private var nearbyHelpers: [HelperLocation] = []
    @State private var isLoading = false
    @State private var mapRegion: MKCoordinateRegion

    private let nearbyThresholdMeters: CLLocationDistance = 10_000

    init(helperCoordinate: CLLocationCoordinate2D) {
        self.helperCoordinate = helperCoordinate
        _mapRegion = State(initialValue: MKCoordinateRegion(
            center: helperCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        ))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NearbyHelpersRadiusMapRepresentable(
                userCoordinate: helperCoordinate,
                nearbyHelpers: nearbyHelpers,
                radiusMeters: nearbyThresholdMeters
            )
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
            mapRegion = MKCoordinateRegion(
                center: helperCoordinate,
                latitudinalMeters: nearbyThresholdMeters * 2.4,
                longitudinalMeters: nearbyThresholdMeters * 2.4
            )
        } catch {
            print("Error loading nearby helpers: \(error.localizedDescription)")
        }
    }
}

private struct NearbyHelpersRadiusMapRepresentable: UIViewRepresentable {
    let userCoordinate: CLLocationCoordinate2D
    let nearbyHelpers: [HelperLocation]
    let radiusMeters: CLLocationDistance

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        let userPin = MKPointAnnotation()
        userPin.title = "You"
        userPin.coordinate = userCoordinate
        mapView.addAnnotation(userPin)

        let helperPins: [MKPointAnnotation] = nearbyHelpers.map { helper in
            let pin = MKPointAnnotation()
            pin.title = "Helper"
            pin.coordinate = helper.coordinate
            return pin
        }
        mapView.addAnnotations(helperPins)

        let radiusCircle = MKCircle(center: userCoordinate, radius: radiusMeters)
        mapView.addOverlay(radiusCircle)

        let visibleRegion = MKCoordinateRegion(
            center: userCoordinate,
            latitudinalMeters: radiusMeters * 2.4,
            longitudinalMeters: radiusMeters * 2.4
        )
        mapView.setRegion(visibleRegion, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "NearbyHelpersPin"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.canShowCallout = true

            if annotation.title ?? "" == "You" {
                view.markerTintColor = .systemRed
                view.glyphImage = UIImage(systemName: "location.fill")
            } else {
                view.markerTintColor = UIColor(AppTheme.primaryBlue)
                view.glyphImage = UIImage(systemName: "person.fill")
            }

            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKCircleRenderer(circle: circle)
            renderer.strokeColor = UIColor.systemRed.withAlphaComponent(0.8)
            renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.10)
            renderer.lineWidth = 2
            return renderer
        }
    }
}

#Preview {
    NearbyHelpersMapView(
        helperCoordinate: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783)
    )
}
