import Combine
import CoreLocation
import SwiftUI

struct IncomingRequestsView: View {
    enum Scope {
        case helpZoneOnly
        case helpZoneAndGlobal
    }

    @EnvironmentObject private var session: AppSession

    @State private var isShowingHelperModeSheet = false
    @State private var selectedScope: Scope = .helpZoneAndGlobal

    @State private var requests: [IncomingRequest] = []
    @State private var isLoadingRequests = false
    @State private var loadErrorMessage: String?

    @StateObject private var locationManager = IncomingLocationManager()

    private let nearbyThresholdMeters: CLLocationDistance = 5000

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(title: "StreetAssist")

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    helperModeCard
                    scopeSelector
                    pointsCard
                    smallStatsRow

                    if session.isHelperEnabled {
                        incomingRequestsSection
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .background(AppTheme.screenBackground)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !session.isHelperEnabled {
                isShowingHelperModeSheet = true
            }
            locationManager.requestAccess()
            Task { await loadIncomingRequests() }
        }
        .onChange(of: session.isHelperEnabled) { enabled in
            if enabled {
                isShowingHelperModeSheet = false
                Task { await loadIncomingRequests() }
            } else {
                isShowingHelperModeSheet = true
                requests = []
            }
        }
        .onChange(of: selectedScope) { _ in
            Task { await loadIncomingRequests() }
        }
        .onChange(of: locationManager.location) { _ in
            Task { await loadIncomingRequests() }
        }
        .refreshable {
            await loadIncomingRequests()
        }
        .sheet(isPresented: $isShowingHelperModeSheet) {
            if #available(iOS 16.4, *) {
                HelperModeRequiredSheetView(
                    isPresented: $isShowingHelperModeSheet,
                    onTurnOnNow: { session.isHelperEnabled = true }
                )
                .presentationDetents([.fraction(0.42)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            } else if #available(iOS 16.0, *) {
                HelperModeRequiredSheetView(
                    isPresented: $isShowingHelperModeSheet,
                    onTurnOnNow: { session.isHelperEnabled = true }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            } else {
                HelperModeRequiredSheetView(
                    isPresented: $isShowingHelperModeSheet,
                    onTurnOnNow: { session.isHelperEnabled = true }
                )
            }
        }
    }

    private var helperModeCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Helper Mode")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(session.isHelperEnabled ? "Currently ON" : "Currently OFF")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(session.isHelperEnabled ? AppTheme.primaryBlue : AppTheme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $session.isHelperEnabled)
                .labelsHidden()
                .tint(AppTheme.primaryBlue)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }

    private var scopeSelector: some View {
        HStack(spacing: 12) {
            scopePill(title: "Help-Zone Only", isSelected: selectedScope == .helpZoneOnly) {
                selectedScope = .helpZoneOnly
            }
            scopePill(title: "Help-Zone + Global", isSelected: selectedScope == .helpZoneAndGlobal) {
                selectedScope = .helpZoneAndGlobal
            }
        }
    }

    private func scopePill(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? AppTheme.primaryBlue : AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: isSelected ? 0 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var pointsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Points")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("1,450")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)

                Text("+120 today")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.liveGreen)

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }

    private var smallStatsRow: some View {
        HStack(spacing: 12) {
            smallStatCard(title: "Weekly Assists", value: "12")
            smallStatCard(title: "Current Streak", value: "6 Days", valueColor: AppTheme.categoryOrange, trailingIcon: "flame.fill")
        }
    }

    private func smallStatCard(
        title: String,
        value: String,
        valueColor: Color = AppTheme.textPrimary,
        trailingIcon: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(valueColor)

                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(valueColor)
                        .offset(y: -1)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }

    private var incomingRequestsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("Nearby Help Requests")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Text("\(requests.count) live nearby")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)
            }
            .padding(.top, 6)

            if isLoadingRequests {
                ProgressView("Loading requests...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if let loadErrorMessage {
                Text(loadErrorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            } else if locationManager.location == nil {
                Text("Enable location access to receive nearby requests.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            } else if requests.isEmpty {
                Text("No nearby requests right now.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            } else {
                VStack(spacing: 14) {
                    ForEach(requests) { request in
                        IncomingRequestCardView(request: request)
                    }
                }
            }
        }
    }

    private func loadIncomingRequests() async {
        guard session.isHelperEnabled else {
            requests = []
            return
        }

        guard let helperLocation = locationManager.location else {
            requests = []
            return
        }

        isLoadingRequests = true
        loadErrorMessage = nil
        defer { isLoadingRequests = false }

        do {
            let fetched = try await HelpRequestService.shared.fetchOpenRequests()

            let filtered = fetched
                .filter { request in
                    switch selectedScope {
                    case .helpZoneOnly:
                        return request.scope == .helpZoneOnly
                    case .helpZoneAndGlobal:
                        return request.scope == .helpZoneOnly || request.scope == .helpZoneAndGlobal
                    }
                }
                .compactMap { request -> IncomingRequest? in
                    let requestLocation = CLLocation(latitude: request.latitude, longitude: request.longitude)
                    let distance = helperLocation.distance(from: requestLocation)
                    guard distance <= nearbyThresholdMeters else {
                        return nil
                    }

                    return IncomingRequest(
                        category: categoryText(for: request.category),
                        categoryStyle: categoryStyle(for: request.category),
                        timeAgo: relativeTime(from: request.createdAt),
                        distance: distanceText(for: distance),
                        timeSortValue: request.createdAt.timeIntervalSince1970,
                        title: titleText(for: request),
                        subtitle: subtitleText(for: request)
                    )
                }
                .sorted { $0.timeSortValue > $1.timeSortValue }

            requests = filtered
        } catch {
            requests = []
            loadErrorMessage = "Unable to load requests: \(error.localizedDescription)"
        }
    }

    private func categoryText(for category: HelpCategory) -> String {
        switch category {
        case .technicalAndRepair:
            return "Technical"
        case .physicalAndLogistics:
            return "Physical"
        case .roadsideAndEmergency:
            return "Roadside"
        case .errandsAndSocial:
            return "Errands"
        }
    }

    private func categoryStyle(for category: HelpCategory) -> IncomingRequest.TagStyle {
        switch category {
        case .technicalAndRepair:
            return .orange
        case .physicalAndLogistics:
            return .gray
        case .roadsideAndEmergency:
            return .green
        case .errandsAndSocial:
            return .gray
        }
    }

    private func titleText(for request: HelpRequest) -> String {
        switch request.category {
        case .technicalAndRepair:
            return "Technical Help Needed"
        case .physicalAndLogistics:
            return "Physical Help Needed"
        case .roadsideAndEmergency:
            return "Roadside Emergency"
        case .errandsAndSocial:
            return "Errand Assistance Needed"
        }
    }

    private func subtitleText(for request: HelpRequest) -> String {
        let trimmed = request.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 56 {
            return trimmed
        }
        return String(trimmed.prefix(56)) + "..."
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func distanceText(for meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return "\(Int(meters.rounded()))M AWAY"
        }

        let km = meters / 1000
        return String(format: "%.1fKM AWAY", km)
    }
}

private struct IncomingRequest: Identifiable {
    enum TagStyle {
        case gray
        case orange
        case green

        var background: Color {
            switch self {
            case .gray:
                return Color.black.opacity(0.07)
            case .orange:
                return AppTheme.categoryOrangeBackground
            case .green:
                return AppTheme.categoryGreenBackground
            }
        }

        var foreground: Color {
            switch self {
            case .gray:
                return AppTheme.textSecondary
            case .orange:
                return AppTheme.categoryOrange
            case .green:
                return AppTheme.categoryGreen
            }
        }
    }

    let id = UUID()

    let category: String
    let categoryStyle: TagStyle
    let timeAgo: String
    let distance: String?

    let timeSortValue: TimeInterval

    var zone: String? = nil
    var zoneStyle: TagStyle? = nil

    let title: String
    let subtitle: String
}

private final class IncomingLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestAccess() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            return
        }

        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

private struct IncomingRequestCardView: View {
    let request: IncomingRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TagPill(text: request.category, style: request.categoryStyle)

                if let zone = request.zone, let zoneStyle = request.zoneStyle {
                    TagPill(text: zone, style: zoneStyle)
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .bold))
                    Text(request.timeAgo)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(AppTheme.textSecondary)

                Spacer(minLength: 0)

                if let distance = request.distance {
                    Text(distance)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.70))
                        .clipShape(Capsule())
                }
            }

            Text(request.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(request.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                // Accept flow will be wired later
            } label: {
                Text("Accept")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
    }
}

private struct TagPill: View {
    let text: String
    let style: IncomingRequest.TagStyle

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(style.background)
            .clipShape(Capsule())
    }
}

#Preview {
    IncomingRequestsView()
        .environmentObject(AppSession())
}
