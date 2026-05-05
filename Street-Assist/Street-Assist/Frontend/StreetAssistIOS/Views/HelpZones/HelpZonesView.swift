import SwiftUI

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
                                    trusted: zone.verificationStatus == .approved
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
            await loadZoneOnlyRequests()
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
                                DispatchQueue.main.async { isShowingJoinZoneScannerSheet = false }
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
                            DispatchQueue.main.async { isShowingJoinZoneScannerSheet = false }
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
        .sheet(isPresented: $isShowingJoinZoneManualSheet) {
            if #available(iOS 16.4, *) {
                JoinHelpZoneManualCodeSheetView(isPresented: $isShowingJoinZoneManualSheet)
                    .presentationDetents([.fraction(0.52)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            } else if #available(iOS 16.0, *) {
                JoinHelpZoneManualCodeSheetView(isPresented: $isShowingJoinZoneManualSheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                JoinHelpZoneManualCodeSheetView(isPresented: $isShowingJoinZoneManualSheet)
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
    }

    private func loadZoneOnlyRequests() async {
        isLoadingRequests = true
        defer { isLoadingRequests = false }

        do {
            var allRequests: [HelpRequest] = []

            for zone in joinedZones {
                let requests = try await HelpZoneService.shared.fetchZoneOnlyRequests(zoneId: zone.id)
                allRequests.append(contentsOf: requests)
            }

            // Sort by created_at descending
            zoneOnlyRequests = allRequests.sorted { $0.createdAt > $1.createdAt }
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
                // wired later
            } label: {
                Text("Help Out")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primaryBlue)
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
        trusted: Bool
    ) -> some View {
        Button {
            // wired later
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

#Preview {
    NavigationStack {
        HelpZonesView(onBack: {})
            .toolbar(.hidden, for: .navigationBar)
    }
}
