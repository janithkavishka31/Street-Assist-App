import Combine
import CoreLocation
import MapKit
import SwiftUI
import Supabase

struct HelpZonesView: View {
    var onBack: (() -> Void)?

    @State private var isShowingJoinZoneScannerSheet = false
    @State private var isShowingJoinZoneManualSheet = false
    @State private var isShowingCreateZoneSheet = false
    @State private var joinedZones: [HelpZone] = []
    @State private var isLoadingZones: Bool = false
    @State private var zoneOnlyRequests: [HelpRequest] = []
    @State private var isLoadingRequests: Bool = false
    @State private var joinErrorMessage: String?
    @State private var joinSuccessMessage: String?
    @State private var selectedZone: HelpZone?
    @State private var acceptedRequestIDs: Set<UUID> = []
    @State private var selectedZoneRequestForAccept: HelpRequest?
    @State private var selectedAcceptedZoneRequest: HelpRequest?

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(
                title: "Help Zones",
                leadingStyle: .back,
                trailingStyle: .avatar,
                onBackTap: { onBack?() }
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("My Help-Zones.")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.top, 10)

                    HStack(spacing: 14) {
                        actionCard(
                            title: "Join Zone",
                            icon: "qrcode.viewfinder",
                            isPrimary: true,
                            onTap: { isShowingJoinZoneScannerSheet = true }
                        )

                        actionCard(
                            title: "Create Zone",
                            icon: "checkmark.shield",
                            isPrimary: false,
                            onTap: { isShowingCreateZoneSheet = true }
                        )
                    }

                    HStack(alignment: .center, spacing: 10) {
                        Text("My Zones")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        if isLoadingZones {
                            Text("...")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.06))
                                .clipShape(Capsule())
                        } else {
                            Text("\(joinedZones.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Capsule())
                        }

                        Spacer()
                    }

                    VStack(spacing: 14) {
                        if isLoadingZones {
                            ProgressView()
                        } else if joinedZones.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("You haven't joined any zones yet.")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary)

                                Text("Join a zone or create one to see it here.")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                        } else {
                            ForEach(joinedZones) { zone in
                                zoneRow(
                                    icon: "building.2.fill",
                                    iconBackground: AppTheme.categoryBlueBackground,
                                    iconForeground: AppTheme.primaryBlue,
                                    title: zone.zoneName,
                                    subtitle: zone.organizationName,
                                    trusted: zone.verificationStatus == .approved,
                                    onTap: { selectedZone = zone }
                                )
                            }
                        }
                    }

                    HStack {
                        Text("Zone-Only Requests")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        Spacer()

                        Button {
                            // wired later
                        } label: {
                            Text("View All")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.primaryBlue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 6)

                    if isLoadingRequests {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else if zoneOnlyRequests.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No zone-only requests yet")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)

                            Text("Create a request or wait for zone members to post.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                    } else {
                        VStack(spacing: 14) {
                            ForEach(zoneOnlyRequests) { request in
                                zoneRequestCardForRequest(request)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .background(AppTheme.screenBackground)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadJoinedZones()
        }
        .sheet(isPresented: $isShowingJoinZoneScannerSheet) {
                if #available(iOS 16.4, *) {
                JoinHelpZoneScannerSheetView(
                    isPresented: $isShowingJoinZoneScannerSheet,
                    onManualEntry: { isShowingJoinZoneManualSheet = true },
                    onScanned: { code in
                        Task {
                                do {
                                    _ = try await HelpZoneService.shared.joinZone(joinCode: code)
                                    // refresh joined zones and close scanner
                                    await loadJoinedZones()
                                    DispatchQueue.main.async {
                                        joinSuccessMessage = "Successfully joined zone."
                                        isShowingJoinZoneScannerSheet = false
                                    }
                                } catch {
                                    DispatchQueue.main.async {
                                        isShowingJoinZoneScannerSheet = false
                                        joinErrorMessage = error.localizedDescription
                                    }
                                }
                        }
                    }
                )
                .presentationDetents([.fraction(0.78)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                } else if #available(iOS 16.0, *) {
                JoinHelpZoneScannerSheetView(
                    isPresented: $isShowingJoinZoneScannerSheet,
                    onManualEntry: { isShowingJoinZoneManualSheet = true },
                    onScanned: { code in
                        Task {
                            do {
                                _ = try await HelpZoneService.shared.joinZone(joinCode: code)
                                await loadJoinedZones()
                                DispatchQueue.main.async {
                                    joinSuccessMessage = "Successfully joined zone."
                                    isShowingJoinZoneScannerSheet = false
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    isShowingJoinZoneScannerSheet = false
                                    joinErrorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            } else {
                JoinHelpZoneScannerSheetView(
                    isPresented: $isShowingJoinZoneScannerSheet,
                    onManualEntry: { isShowingJoinZoneManualSheet = true },
                    onScanned: { code in Task {
                        do {
                            _ = try await HelpZoneService.shared.joinZone(joinCode: code)
                            await loadJoinedZones()
                            DispatchQueue.main.async {
                                joinSuccessMessage = "Successfully joined zone."
                                isShowingJoinZoneScannerSheet = false
                            }
                        } catch {
                            DispatchQueue.main.async {
                                isShowingJoinZoneScannerSheet = false
                                joinErrorMessage = error.localizedDescription
                            }
                        }
                    } }
                )
            }
        }
        .alert("Join Zone Failed", isPresented: Binding(
            get: { joinErrorMessage != nil },
            set: { if !$0 { joinErrorMessage = nil } }
        ), actions: {
            Button("OK", role: .cancel) { joinErrorMessage = nil }
        }, message: {
            Text(joinErrorMessage ?? "Unable to join zone.")
        })
        .alert("Joined Zone", isPresented: Binding(
            get: { joinSuccessMessage != nil },
            set: { if !$0 { joinSuccessMessage = nil } }
        ), actions: {
            Button("OK", role: .cancel) { joinSuccessMessage = nil }
        }, message: {
            Text(joinSuccessMessage ?? "Successfully joined zone.")
        })
        .sheet(isPresented: $isShowingJoinZoneManualSheet) {
            if #available(iOS 16.4, *) {
                JoinHelpZoneManualCodeSheetView(
                    isPresented: $isShowingJoinZoneManualSheet,
                    onJoined: {
                        Task { await loadJoinedZones() }
                        joinSuccessMessage = "Successfully joined zone."
                    }
                )
                    .presentationDetents([.fraction(0.52)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            } else if #available(iOS 16.0, *) {
                JoinHelpZoneManualCodeSheetView(
                    isPresented: $isShowingJoinZoneManualSheet,
                    onJoined: {
                        Task { await loadJoinedZones() }
                        joinSuccessMessage = "Successfully joined zone."
                    }
                )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                JoinHelpZoneManualCodeSheetView(
                    isPresented: $isShowingJoinZoneManualSheet,
                    onJoined: {
                        Task { await loadJoinedZones() }
                        joinSuccessMessage = "Successfully joined zone."
                    }
                )
            }
        }
        .sheet(isPresented: $isShowingCreateZoneSheet) {
            if #available(iOS 16.4, *) {
                CreateHelpZoneSheetView(isPresented: $isShowingCreateZoneSheet)
                    .presentationDetents([.fraction(0.90)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            } else if #available(iOS 16.0, *) {
                CreateHelpZoneSheetView(isPresented: $isShowingCreateZoneSheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            } else {
                CreateHelpZoneSheetView(isPresented: $isShowingCreateZoneSheet)
            }
        }
        .sheet(item: $selectedZone) { zone in
            ZoneDetailsSheetView(zone: zone)
        }
        .sheet(item: $selectedZoneRequestForAccept) { request in
            ZoneRequestAcceptSheetView(
                request: request,
                onAccepted: {
                    acceptedRequestIDs.insert(request.id)
                    Task { await loadZoneOnlyRequests() }
                }
            )
        }
        .sheet(item: $selectedAcceptedZoneRequest) { request in
            ZoneAcceptedRequestSheetView(request: request)
        }
    }

    private func loadJoinedZones() async {
        isLoadingZones = true
        do {
            let zones = try await HelpZoneService.shared.fetchJoinedZones()
            // sort by name for stable ordering
            joinedZones = zones.sorted { $0.zoneName.lowercased() < $1.zoneName.lowercased() }
        } catch {
            print("Failed to load joined zones:", error)
            joinedZones = []
        }
        isLoadingZones = false
        await loadZoneOnlyRequests()
    }

    private func loadZoneOnlyRequests() async {
        isLoadingRequests = true
        defer { isLoadingRequests = false }

        do {
            let auth = SupabaseManager.shared.client.auth
            let currentUserID = auth.currentUser?.id ?? auth.currentSession?.user.id
            var allRequests: [HelpRequest] = []
            let acceptedByCurrentHelper = try await HelpRequestService.shared.fetchAcceptedRequestsForCurrentHelper()

            for zone in joinedZones {
                let requests = try await HelpZoneService.shared.fetchZoneOnlyRequests(zoneId: zone.id)
                allRequests.append(contentsOf: requests)
            }
            allRequests.append(contentsOf: acceptedByCurrentHelper)
            allRequests = Dictionary(uniqueKeysWithValues: allRequests.map { ($0.id, $0) })
                .map(\.value)

            let acceptances = try await HelpRequestService.shared.fetchAcceptancesForCurrentUser()
            acceptedRequestIDs = Set(acceptances.map(\.requestId))

            // Sort by created_at descending
            zoneOnlyRequests = allRequests
                .filter { request in
                    guard let currentUserID else { return true }
                    return request.requesterUserId != currentUserID
                }
                .filter { request in
                    request.scope == .helpZoneOnly
                }
                .filter { request in
                    guard let zoneID = request.zoneId else { return false }
                    return joinedZones.contains(where: { $0.id == zoneID })
                }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("Failed to load zone requests:", error)
            zoneOnlyRequests = []
        }
    }

    private func zoneRequestCardForRequest(_ request: HelpRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.serviceTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("• \(relativeTime(from: request.createdAt))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(categoryText(for: request.category))
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.9))
                .clipShape(Capsule())
            }

            Text(request.description)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)

            Button {
                if acceptedRequestIDs.contains(request.id) {
                    selectedAcceptedZoneRequest = request
                } else {
                    selectedZoneRequestForAccept = request
                }
            } label: {
                Text(acceptedRequestIDs.contains(request.id) ? "View" : "Help Out")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(acceptedRequestIDs.contains(request.id) ? AppTheme.categoryGreen : AppTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    private func relativeTime(from date: Date) -> String {
        let now = Date()
        let seconds = Int(now.timeIntervalSince(date))

        if seconds < 60 {
            return "\(seconds)s ago"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
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

    private func actionCard(title: String, icon: String, isPrimary: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isPrimary ? Color.white.opacity(0.18) : AppTheme.categoryBlueBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isPrimary ? .white : AppTheme.primaryBlue)
                    )

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isPrimary ? .white : AppTheme.textPrimary)

                Spacer(minLength: 0)
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: [AppTheme.primaryBlueDark, AppTheme.primaryBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        AppTheme.cardBackground
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }

    private func zoneRow(
        icon: String,
        iconBackground: Color,
        iconForeground: Color,
        title: String,
        subtitle: String,
        trusted: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(iconBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(iconForeground)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)

                        if trusted {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Trusted")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(AppTheme.primaryBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.categoryBlueBackground)
                            .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct ZoneDetailsSheetView: View {
    let zone: HelpZone

    @Environment(\.dismiss) private var dismiss
    @State private var members: [HelpZoneService.ZoneMemberProfile] = []
    @State private var isLoadingMembers = false
    @State private var loadError: String?

    private var helperEnabledCount: Int {
        members.filter(\.isHelperEnabled).count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(zone.zoneName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(zone.organizationName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
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
            .padding(.top, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        statCard(title: "Members", value: "\(members.count)", icon: "person.3.fill", color: AppTheme.primaryBlue)
                        statCard(title: "Helpers ON", value: "\(helperEnabledCount)", icon: "bolt.fill", color: AppTheme.liveGreen)
                    }

                    if let loadError {
                        Text(loadError)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                    } else if isLoadingMembers {
                        ProgressView("Loading members...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    } else if members.isEmpty {
                        Text("No active members in this zone yet.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(members) { member in
                                memberRow(member)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.screenBackground)
        .task {
            await loadMembers()
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
    }

    private func memberRow(_ member: HelpZoneService.ZoneMemberProfile) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.black.opacity(0.08))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(member.fullName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(member.role == .creator ? "Creator" : "Member")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text(member.isHelperEnabled ? "Helper ON" : "Helper OFF")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(member.isHelperEnabled ? AppTheme.liveGreen : AppTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(member.isHelperEnabled ? AppTheme.categoryGreenBackground : Color.black.opacity(0.06))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func loadMembers() async {
        isLoadingMembers = true
        loadError = nil
        defer { isLoadingMembers = false }

        do {
            members = try await HelpZoneService.shared.fetchZoneMembers(zoneId: zone.id)
        } catch {
            members = []
            loadError = "Unable to load zone members: \(error.localizedDescription)"
        }
    }
}

private struct ZoneRequestAcceptSheetView: View {
    let request: HelpRequest
    var onAccepted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = HelpZoneSheetLocationManager()
    @State private var isAccepting = false
    @State private var acceptanceMessage: String?

    private var requesterCoordinate: CLLocationCoordinate2D? {
        let coordinate = CLLocationCoordinate2D(latitude: request.latitude, longitude: request.longitude)
        return coordinate.isValidMapCoordinate ? coordinate : nil
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Request Details")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
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

            VStack(alignment: .leading, spacing: 10) {
                Text(request.serviceTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(request.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))

            if
                let helperCoordinate = locationManager.location?.coordinate,
                helperCoordinate.isValidMapCoordinate,
                let requesterCoordinate
            {
                HelpZoneRouteMapView(
                    helperCoordinate: helperCoordinate,
                    requesterCoordinate: requesterCoordinate
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                Text("Allow location access to see route details.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            }

            if let acceptanceMessage {
                Text(acceptanceMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                acceptRequest()
            } label: {
                if isAccepting {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Text("Accept Request")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .buttonStyle(.plain)
            .disabled(isAccepting)
        }
        .padding(20)
        .background(AppTheme.screenBackground)
        .onAppear {
            locationManager.requestAccess()
        }
    }

    private func acceptRequest() {
        guard !isAccepting else { return }
        isAccepting = true
        acceptanceMessage = nil

        Task {
            do {
                _ = try await HelpRequestService.shared.acceptRequest(requestId: request.id)
                await MainActor.run {
                    onAccepted()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    acceptanceMessage = "Failed to accept request: \(error.localizedDescription)"
                    isAccepting = false
                }
            }
        }
    }
}

private struct ZoneAcceptedRequestSheetView: View {
    let request: HelpRequest

    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = HelpZoneSheetLocationManager()
    @State private var isCompletingTask = false
    @State private var taskCompletionMessage: String?

    private var requesterCoordinate: CLLocationCoordinate2D? {
        let coordinate = CLLocationCoordinate2D(latitude: request.latitude, longitude: request.longitude)
        return coordinate.isValidMapCoordinate ? coordinate : nil
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Accepted Request")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
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

            VStack(alignment: .leading, spacing: 10) {
                Text(request.serviceTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(request.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))

            if
                let helperCoordinate = locationManager.location?.coordinate,
                helperCoordinate.isValidMapCoordinate,
                let requesterCoordinate
            {
                HelpZoneRouteMapView(
                    helperCoordinate: helperCoordinate,
                    requesterCoordinate: requesterCoordinate
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                Text("Allow location access to see route details.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            }

            if let taskCompletionMessage {
                Text(taskCompletionMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                markTaskCompleted()
            } label: {
                if isCompletingTask {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    Text("Mark Task as Completed")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .buttonStyle(.plain)
            .disabled(isCompletingTask)
        }
        .padding(20)
        .background(AppTheme.screenBackground)
        .onAppear {
            locationManager.requestAccess()
        }
    }

    private func markTaskCompleted() {
        guard !isCompletingTask else { return }
        isCompletingTask = true
        taskCompletionMessage = nil

        Task {
            do {
                try await HelpRequestService.shared.markHelperTaskCompleted(requestId: request.id)
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
}

private final class HelpZoneSheetLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 25
    }

    func requestAccess() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestSingleLocationFix()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.location = nil
            }
        @unknown default:
            DispatchQueue.main.async {
                self.location = nil
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.requestAccess()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        DispatchQueue.main.async {
            self.location = latest
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.location = nil
        }
        print("Help zone sheet location error: \(error.localizedDescription)")
    }

    private func requestSingleLocationFix() {
        // One-shot location is safer for transient modal sheets.
        manager.requestLocation()
    }
}

private struct HelpZoneRouteMapView: UIViewRepresentable {
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
        guard helperCoordinate.isValidMapCoordinate, requesterCoordinate.isValidMapCoordinate else {
            mapView.removeAnnotations(mapView.annotations)
            mapView.removeOverlays(mapView.overlays)
            return
        }

        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        let helperPin = MKPointAnnotation()
        helperPin.title = "You"
        helperPin.coordinate = helperCoordinate

        let requesterPin = MKPointAnnotation()
        requesterPin.title = "Requester"
        requesterPin.coordinate = requesterCoordinate

        mapView.addAnnotations([helperPin, requesterPin])
        context.coordinator.drawRoute(
            on: mapView,
            helperCoordinate: helperCoordinate,
            requesterCoordinate: requesterCoordinate
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var directions: MKDirections?

        func drawRoute(on mapView: MKMapView, helperCoordinate: CLLocationCoordinate2D, requesterCoordinate: CLLocationCoordinate2D) {
            directions?.cancel()

            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: helperCoordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: requesterCoordinate))
            request.transportType = .automobile

            let directions = MKDirections(request: request)
            self.directions = directions

            directions.calculate { response, _ in
                DispatchQueue.main.async {
                    if let route = response?.routes.first {
                        mapView.addOverlay(route.polyline)
                        mapView.setVisibleMapRect(
                            route.polyline.boundingMapRect,
                            edgePadding: UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30),
                            animated: true
                        )
                        return
                    }

                    let points = [helperCoordinate, requesterCoordinate]
                    let fallback = MKPolyline(coordinates: points, count: points.count)
                    mapView.addOverlay(fallback)
                    mapView.showAnnotations(mapView.annotations, animated: true)
                }
            }
        }

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

private extension CLLocationCoordinate2D {
    var isValidMapCoordinate: Bool {
        CLLocationCoordinate2DIsValid(self)
            && latitude.isFinite
            && longitude.isFinite
            && abs(latitude) <= 90
            && abs(longitude) <= 180
    }
}

#Preview {
    NavigationStack {
        HelpZonesView(onBack: {})
            .toolbar(.hidden, for: .navigationBar)
    }
}
