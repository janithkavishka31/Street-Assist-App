import Combine
import CoreLocation
import MapKit
import Supabase
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

    @State private var helperSkillKeys: Set<SkillKey> = []
    @State private var didLoadSkills = false

    @State private var selectedRequest: IncomingRequest?
    @State private var selectedViewRequest: IncomingRequest? // For "View" modal
    @State private var acceptedRequestIds: Set<UUID> = [] // Track which requests are accepted
    @State private var activeAcceptedRequestId: UUID?
    @State private var joinedZoneIDs: Set<UUID> = []
    @State private var helperTotalPoints: Int = 0
    @State private var helperTodayPoints: Int = 0
    @State private var helperWeeklyAssists: Int = 0
    @State private var helperCurrentStreak: Int = 0

    @StateObject private var locationManager = IncomingLocationManager()
    @State private var loadRequestsTask: Task<Void, Never>?

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
            triggerLoadIncomingRequests()
            Task { await loadHelperStats() }
        }
        .onChange(of: session.isHelperEnabled) { enabled in
            if enabled {
                isShowingHelperModeSheet = false
                triggerLoadIncomingRequests()
                Task { await loadHelperStats() }
            } else {
                isShowingHelperModeSheet = true
                requests = []
                loadRequestsTask?.cancel()
            }
        }
        .onChange(of: selectedScope) { _ in
            triggerLoadIncomingRequests()
        }
        .onChange(of: locationManager.location) { _ in
            triggerLoadIncomingRequests()
        }
        .refreshable {
            await loadIncomingRequests()
            await loadHelperStats()
        }
        .onDisappear {
            loadRequestsTask?.cancel()
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
        .sheet(item: $selectedRequest) { request in
            IncomingRequestDetailSheetView(
                request: request,
                helperCoordinate: locationManager.location?.coordinate,
                onAccept: {
                    acceptedRequestIds.insert(request.requestId)
                }
            )
        }
        .sheet(item: $selectedViewRequest) { request in
            if let helperCoordinate = locationManager.location?.coordinate {
                ViewAcceptedRequestView(
                    request: request,
                    helperCoordinate: helperCoordinate,
                    requesterCoordinate: request.requesterCoordinate
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
                Text("\(helperTotalPoints)")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)

                Text("+\(helperTodayPoints) today")
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
            smallStatCard(title: "Weekly Assists", value: "\(helperWeeklyAssists)")
            smallStatCard(
                title: "Current Streak",
                value: "\(helperCurrentStreak) Days",
                valueColor: AppTheme.categoryOrange,
                trailingIcon: "flame.fill"
            )
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
                Text(locationMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            } else if didLoadSkills && helperSkillKeys.isEmpty {
                Text("Add helper skills to receive matching requests.")
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
                    if activeAcceptedRequestId != nil {
                        Text("Finish your current accepted request before accepting another one.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    ForEach(requests) { request in
                        let isAccepted = acceptedRequestIds.contains(request.requestId)
                        let isDisabledForNewAccept =
                            activeAcceptedRequestId != nil
                            && !isAccepted
                            && request.requestId != activeAcceptedRequestId
                        IncomingRequestCardView(
                            request: request,
                            isAccepted: isAccepted,
                            isDisabled: isDisabledForNewAccept,
                            onTap: {
                                guard !isDisabledForNewAccept else { return }
                                if isAccepted {
                                    selectedViewRequest = request
                                } else {
                                    selectedRequest = request
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var locationMessage: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "Allow location access to receive nearby requests."
        case .denied, .restricted:
            return "Location access is turned off for StreetAssist. Enable it in Settings to receive nearby requests."
        case .authorizedWhenInUse, .authorizedAlways:
            return "Waiting for a location fix..."
        @unknown default:
            return "Enable location access to receive nearby requests."
        }
    }

    private func loadIncomingRequests() async {
        guard session.isHelperEnabled else {
            requests = []
            acceptedRequestIds = []
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
            let auth = SupabaseManager.shared.client.auth
            let currentUserID = auth.currentUser?.id ?? auth.currentSession?.user.id

            if !didLoadSkills {
                helperSkillKeys = try await HelpRequestService.shared.fetchCurrentUserSkillKeys()
                didLoadSkills = true
            }

            joinedZoneIDs = try await HelpZoneService.shared.fetchJoinedZoneIDsForCurrentUser()

            let openRequests = try await HelpRequestService.shared.fetchOpenRequests()
            let acceptedByCurrentHelper = try await HelpRequestService.shared.fetchAcceptedRequestsForCurrentHelper()
            let acceptances = try await HelpRequestService.shared.fetchAcceptancesForCurrentUser()
            let activeAcceptances = acceptances
                .filter { $0.completedAt == nil && $0.canceledAt == nil }
                .sorted { $0.acceptedAt < $1.acceptedAt }
            let activeAcceptedRequestIDs = Set(activeAcceptances.map(\.requestId))

            acceptedRequestIds = activeAcceptedRequestIDs
            activeAcceptedRequestId = activeAcceptances.first?.requestId

            let fetched = Dictionary(uniqueKeysWithValues: (openRequests + acceptedByCurrentHelper).map { ($0.id, $0) })
                .map(\.value)

            let filtered = fetched
                .filter { request in
                    guard request.status == .accepted else { return true }
                    return activeAcceptedRequestIDs.contains(request.id)
                }
                .filter { request in
                    guard let currentUserID else { return true }
                    return request.requesterUserId != currentUserID
                }
                .filter { request in
                    guard request.scope == .helpZoneOnly else { return true }
                    guard let zoneID = request.zoneId else { return false }
                    return joinedZoneIDs.contains(zoneID)
                }
                .filter { request in
                    helperSkillKeys.contains(skillKey(for: request.category))
                }
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
                        requestId: request.id,
                        requesterUserId: request.requesterUserId,
                        category: categoryText(for: request.category),
                        categoryStyle: categoryStyle(for: request.category),
                        timeAgo: relativeTime(from: request.createdAt),
                        distance: distanceText(for: distance),
                        timeSortValue: request.createdAt.timeIntervalSince1970,
                        requesterCoordinate: CLLocationCoordinate2D(
                            latitude: request.latitude,
                            longitude: request.longitude
                        ),
                        title: titleText(for: request),
                        subtitle: subtitleText(for: request),
                        fullDescription: request.description
                    )
                }
                .sorted { lhs, rhs in
                    let lhsIsActive = lhs.requestId == activeAcceptedRequestId
                    let rhsIsActive = rhs.requestId == activeAcceptedRequestId

                    if lhsIsActive != rhsIsActive {
                        return lhsIsActive
                    }

                    return lhs.timeSortValue > rhs.timeSortValue
                }

            await notifyAboutNewRequestsIfNeeded(filtered)

            requests = filtered
        } catch is CancellationError {
            // Ignore expected cancellation from rapid state/location refreshes.
        } catch {
            requests = []
            loadErrorMessage = "Unable to load requests: \(error.localizedDescription)"
        }
    }

    private func triggerLoadIncomingRequests() {
        loadRequestsTask?.cancel()
        loadRequestsTask = Task {
            await loadIncomingRequests()
        }
    }

    private func loadHelperStats() async {
        do {
            let stats = try await HelpRequestService.shared.fetchHelperDashboardStats()
            helperTotalPoints = stats.totalPoints
            helperTodayPoints = stats.todayPoints
            helperWeeklyAssists = stats.weeklyAssists
            helperCurrentStreak = stats.currentStreakDays
        } catch {
            helperTotalPoints = 0
            helperTodayPoints = 0
            helperWeeklyAssists = 0
            helperCurrentStreak = 0
            print("Failed to load helper stats: \(error.localizedDescription)")
        }
    }

    private func notifyAboutNewRequestsIfNeeded(_ latestRequests: [IncomingRequest]) async {
        let latestIDs = Set(latestRequests.map(\.requestId))
        let currentIDs = Set(requests.map(\.requestId))
        let newIDs = currentIDs.isEmpty ? latestIDs : latestIDs.subtracting(currentIDs)
        guard !newIDs.isEmpty else {
            return
        }

        let newRequests = latestRequests.filter { newIDs.contains($0.requestId) }
        for request in newRequests {
            var body = request.subtitle
            if let distance = request.distance {
                body += " • \(distance)"
            }
            await LocalNotificationService.shared.notifyNewRequestIfNeeded(
                requestId: request.requestId,
                title: "New \(request.category) request nearby",
                body: body
            )
        }
    }

    private func skillKey(for category: HelpCategory) -> SkillKey {
        switch category {
        case .technicalAndRepair:
            return .technical
        case .physicalAndLogistics:
            return .physical
        case .roadsideAndEmergency:
            return .roadside
        case .errandsAndSocial:
            return .errands
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

    let requestId: UUID
    let requesterUserId: UUID

    let category: String
    let categoryStyle: TagStyle
    let timeAgo: String
    let distance: String?

    let timeSortValue: TimeInterval

    let requesterCoordinate: CLLocationCoordinate2D

    var zone: String? = nil
    var zoneStyle: TagStyle? = nil

    let title: String
    let subtitle: String
    let fullDescription: String
}

private final class IncomingLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var isUpdatingLocation = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 25
        authorizationStatus = manager.authorizationStatus
    }

    func requestAccess() {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdatingLocation()
        case .denied, .restricted:
            location = nil
        @unknown default:
            location = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdatingLocation()
        case .denied, .restricted:
            location = nil
        case .notDetermined:
            break
        @unknown default:
            location = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        DispatchQueue.main.async {
            self.location = latest
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    private func beginUpdatingLocation() {
        guard !isUpdatingLocation else {
            manager.requestLocation()
            return
        }

        isUpdatingLocation = true
        manager.startUpdatingLocation()
        manager.requestLocation()
    }
}

private struct IncomingRequestCardView: View {
    let request: IncomingRequest
    let isAccepted: Bool
    let isDisabled: Bool
    let onTap: () -> Void

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
                onTap()
            } label: {
                Text(isAccepted ? "View" : "Accept")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isDisabled ? AppTheme.textSecondary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        isDisabled
                            ? AppTheme.cardBackground
                            : (isAccepted ? AppTheme.categoryGreen : AppTheme.primaryBlue)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isDisabled ? AppTheme.border : .clear, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
        .opacity(isDisabled ? 0.55 : 1.0)
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

private struct IncomingRequestDetailSheetView: View {
    let request: IncomingRequest
    let helperCoordinate: CLLocationCoordinate2D?
    var onAccept: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var isAccepting = false
    @State private var acceptanceError: String?
    @State private var requesterPreview: HelpRequestService.RequesterPreview?
    @State private var photoURLs: [String] = []
    @State private var isLoadingAssets = false

    var body: some View {
        VStack(spacing: 12) {
            headerRow

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    infoCard
                    requesterCard
                    photosCard
                    mapCard

                    if let error = acceptanceError {
                        Text(error)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.categoryGreen)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                    }
                }
            }

            Button {
                acceptRequest()
            } label: {
                HStack {
                    if isAccepting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isAccepting ? "Accepting..." : "Accept Request")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(AppTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isAccepting)
            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
        }
        .padding(20)
        .background(AppTheme.screenBackground)
        .task {
            await loadRequestAssets()
        }
    }

    private func acceptRequest() {
        isAccepting = true
        acceptanceError = nil

        Task {
            do {
                _ = try await HelpRequestService.shared.acceptRequest(requestId: request.requestId)
                onAccept()
                DispatchQueue.main.async {
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    acceptanceError = "Failed to accept request: \(error.localizedDescription)"
                    isAccepting = false
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            TagPill(text: request.category, style: request.categoryStyle)
            Text(request.timeAgo)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(10)
                    .background(Color.black.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(request.title)
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text(request.fullDescription)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    private var requesterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Requester")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            if isLoadingAssets && requesterPreview == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let requesterPreview {
                Text(requesterPreview.fullName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                if let phone = requesterPreview.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if let bio = requesterPreview.quickBio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
            } else {
                Text("Requester details unavailable.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Requester Photos")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if !photoURLs.isEmpty {
                    Text("\(photoURLs.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlue)
                }
            }

            if isLoadingAssets && photoURLs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if photoURLs.isEmpty {
                Text("No photos were attached to this request.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoURLs, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    ZStack {
                                        Color.black.opacity(0.06)
                                        Image(systemName: "photo")
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                case .empty:
                                    ZStack {
                                        Color.black.opacity(0.04)
                                        ProgressView()
                                    }
                                @unknown default:
                                    Color.black.opacity(0.04)
                                }
                            }
                            .frame(width: 170, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    @ViewBuilder
    private var mapCard: some View {
        if let helperCoordinate {
            RouteMapView(
                helperCoordinate: helperCoordinate,
                requesterCoordinate: request.requesterCoordinate
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            Text("Waiting for location access...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        }
    }

    @MainActor
    private func loadRequestAssets() async {
        isLoadingAssets = true
        defer { isLoadingAssets = false }
        do {
            async let previewTask = HelpRequestService.shared.fetchRequesterPreview(userId: request.requesterUserId)
            async let photosTask = HelpRequestService.shared.fetchRequestPhotos(requestId: request.requestId)
            let (preview, photos) = try await (previewTask, photosTask)
            requesterPreview = preview
            photoURLs = photos.map(\.photoUrl)
        } catch {
            requesterPreview = nil
            photoURLs = []
        }
    }
}

private struct RouteMapView: UIViewRepresentable {
    let helperCoordinate: CLLocationCoordinate2D
    let requesterCoordinate: CLLocationCoordinate2D

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

        let helperPin = MKPointAnnotation()
        helperPin.title = "You"
        helperPin.coordinate = helperCoordinate

        let requesterPin = MKPointAnnotation()
        requesterPin.title = "Requester"
        requesterPin.coordinate = requesterCoordinate

        mapView.addAnnotations([helperPin, requesterPin])

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: helperCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: requesterCoordinate))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            guard let route = response?.routes.first, error == nil else {
                let region = MKCoordinateRegion(
                    center: helperCoordinate,
                    latitudinalMeters: 2000,
                    longitudinalMeters: 2000
                )
                mapView.setRegion(region, animated: true)
                return
            }

            mapView.addOverlay(route.polyline)
            mapView.setVisibleMapRect(
                route.polyline.boundingMapRect,
                edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40),
                animated: true
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(AppTheme.primaryBlue)
            renderer.lineWidth = 5
            renderer.lineJoin = .round
            return renderer
        }
    }
}

private struct ViewAcceptedRequestView: View {
    let request: IncomingRequest
    let helperCoordinate: CLLocationCoordinate2D
    let requesterCoordinate: CLLocationCoordinate2D

    @Environment(\.dismiss) private var dismiss
    @State private var isCompletingTask = false
    @State private var taskCompletionMessage: String?
    @State private var requesterPreview: HelpRequestService.RequesterPreview?
    @State private var photoURLs: [String] = []
    @State private var isLoadingAssets = false

    var body: some View {
        VStack(spacing: 12) {
            headerRow

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    infoCard
                    requesterCard
                    photosCard
                    mapCard

                    if let taskCompletionMessage {
                        Text(taskCompletionMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                    }
                }
            }

            Button {
                markTaskCompleted()
            } label: {
                HStack {
                    if isCompletingTask {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isCompletingTask ? "Updating..." : "Mark Task as Completed")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isCompletingTask)
            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
        }
        .padding(20)
        .background(AppTheme.screenBackground)
        .task {
            await loadRequestAssets()
        }
    }

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Accepted Request")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                Text(request.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(10)
                    .background(Color.black.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TagPill(text: request.category, style: request.categoryStyle)
                Spacer()
                Text(request.timeAgo)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text(request.fullDescription)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    private var requesterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Requester")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            if isLoadingAssets && requesterPreview == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let requesterPreview {
                Text(requesterPreview.fullName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                if let phone = requesterPreview.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if let bio = requesterPreview.quickBio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }
            } else {
                Text("Requester details unavailable.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Requester Photos")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if !photoURLs.isEmpty {
                    Text("\(photoURLs.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.primaryBlue)
                }
            }

            if isLoadingAssets && photoURLs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if photoURLs.isEmpty {
                Text("No photos were attached to this request.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photoURLs, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case let .success(image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    ZStack {
                                        Color.black.opacity(0.06)
                                        Image(systemName: "photo")
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                case .empty:
                                    ZStack {
                                        Color.black.opacity(0.04)
                                        ProgressView()
                                    }
                                @unknown default:
                                    Color.black.opacity(0.04)
                                }
                            }
                            .frame(width: 170, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    private var mapCard: some View {
        RouteMapView(
            helperCoordinate: helperCoordinate,
            requesterCoordinate: requesterCoordinate
        )
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func markTaskCompleted() {
        guard !isCompletingTask else { return }
        isCompletingTask = true
        taskCompletionMessage = nil

        Task {
            do {
                try await HelpRequestService.shared.markHelperTaskCompleted(requestId: request.requestId)
                await MainActor.run {
                    taskCompletionMessage = "Marked as completed. Waiting for requester confirmation and payment."
                }
            } catch {
                await MainActor.run {
                    taskCompletionMessage = "Unable to mark completion: \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                isCompletingTask = false
            }
        }
    }

    @MainActor
    private func loadRequestAssets() async {
        isLoadingAssets = true
        defer { isLoadingAssets = false }
        do {
            async let previewTask = HelpRequestService.shared.fetchRequesterPreview(userId: request.requesterUserId)
            async let photosTask = HelpRequestService.shared.fetchRequestPhotos(requestId: request.requestId)
            let (preview, photos) = try await (previewTask, photosTask)
            requesterPreview = preview
            photoURLs = photos.map(\.photoUrl)
        } catch {
            requesterPreview = nil
            photoURLs = []
        }
    }
}

#Preview {
    IncomingRequestsView()
        .environmentObject(AppSession())
}
