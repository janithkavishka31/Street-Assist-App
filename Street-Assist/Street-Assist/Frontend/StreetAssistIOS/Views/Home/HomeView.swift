import CoreLocation
import MapKit
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: AppSession
    @State private var selectedScope: HelpScope = .helpZoneOnly
    @State private var isShowingHelpSheet = false
    @State private var pendingCategorySelection: HelpCategory?
    @State private var isShowingTechnicalRepair = false
    @State private var isShowingPhysicalLogistics = false
    @State private var isShowingRoadsideEmergencies = false
    @State private var isShowingErrandsAndSocial = false

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.8199, longitude: -122.4783),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    @State private var nearbyHelpersCount = 0
    @State private var isLoadingHelpers = false
    @State private var isShowingNearbyHelpersMap = false

    @StateObject private var locationManager = HomeLocationManager()
    @State private var activeRequesterTask: HelpRequestService.RequesterActiveTask?
    @State private var isLoadingActiveTask = false
    @State private var requesterMessage: String?
    @State private var isShowingPaymentSheet = false
    @State private var paymentTask: HelpRequestService.RequesterActiveTask?
    @State private var pendingRequesterRequest: HelpRequest?
    @State private var isShowingPendingRequestSheet = false
    @State private var homeScore: Double = 0
    @State private var homeImpactAssists: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            StreetAssistNavBar(title: "StreetAssist")

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    helperToggleCard
                    scopeSelector
                    needAHandCard
                    requesterActiveTaskSection
                    mapPreview
                    statsRow
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }

        }
        .background(AppTheme.screenBackground)
        .sheet(isPresented: $isShowingHelpSheet, onDismiss: {
            switch pendingCategorySelection {
            case .technicalAndRepair:
                isShowingTechnicalRepair = true
            case .physicalAndLogistics:
                isShowingPhysicalLogistics = true
            case .roadsideAndEmergency:
                isShowingRoadsideEmergencies = true
            case .errandsAndSocial:
                isShowingErrandsAndSocial = true
            default:
                break
            }
            pendingCategorySelection = nil
        }) {
            if #available(iOS 16.4, *) {
                HelpRequestSheetView(isPresented: $isShowingHelpSheet) { category in
                    pendingCategorySelection = category
                    isShowingHelpSheet = false
                }
                    .presentationDetents([.fraction(0.78)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            } else if #available(iOS 16.0, *) {
                HelpRequestSheetView(isPresented: $isShowingHelpSheet) { category in
                    pendingCategorySelection = category
                    isShowingHelpSheet = false
                }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            } else {
                HelpRequestSheetView(isPresented: $isShowingHelpSheet) { category in
                    pendingCategorySelection = category
                    isShowingHelpSheet = false
                }
            }
        }
        .navigationDestination(isPresented: $isShowingTechnicalRepair) {
            TechnicalRepairView()
        }
        .navigationDestination(isPresented: $isShowingPhysicalLogistics) {
            PhysicalLogisticsView()
        }
        .navigationDestination(isPresented: $isShowingRoadsideEmergencies) {
            RoadsideEmergenciesView()
        }
        .navigationDestination(isPresented: $isShowingErrandsAndSocial) {
            ErrandsAndSocialView()
        }
        .navigationDestination(isPresented: $isShowingNearbyHelpersMap) {
            if let coordinate = locationManager.location?.coordinate {
                NearbyHelpersMapView(helperCoordinate: coordinate)
            }
        }
        .onAppear {
            locationManager.requestAccess()
            Task {
                await loadHelperStatusFromServer()
                await loadNearbyHelpersCount()
                await loadActiveRequesterTask()
                await loadPendingRequesterRequest()
                await loadHomeStats()
            }
        }
        .onChange(of: session.isHelperEnabled) { _ in
            Task { await updateHelperStatus() }
        }
        .onChange(of: locationManager.location) { _ in
            Task { await loadNearbyHelpersCount() }
        }
        .sheet(isPresented: $isShowingPaymentSheet, onDismiss: {
            Task {
                await loadActiveRequesterTask()
                await loadPendingRequesterRequest()
            }
        }) {
            if let paymentTask {
                RequestPaymentSheetView(
                    task: paymentTask,
                    isPresented: $isShowingPaymentSheet
                )
            }
        }
        .sheet(isPresented: $isShowingPendingRequestSheet) {
            if let pendingRequesterRequest {
                if #available(iOS 16.4, *) {
                    PendingRequestSheetView(request: pendingRequesterRequest)
                        .presentationDetents([.height(470)])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(24)
                } else if #available(iOS 16.0, *) {
                    PendingRequestSheetView(request: pendingRequesterRequest)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                } else {
                    PendingRequestSheetView(request: pendingRequesterRequest)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .streetAssistRequestSubmitted)) { _ in
            Task { await loadPendingRequesterRequest() }
        }
    }

    private var helperToggleCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("I'm a Helper")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Earn points by assisting others")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $session.isHelperEnabled)
                .labelsHidden()
                .tint(AppTheme.liveGreen)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }

    private var scopeSelector: some View {
        HStack(spacing: 12) {
            scopePill(title: "Help-Zone only", isSelected: selectedScope == .helpZoneOnly) {
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

    private var needAHandCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primaryBlueDark, AppTheme.primaryBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 10) {
                Text("Need a Hand?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                Text("Connect with trusted\nhelpers nearby in\nseconds.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    if pendingRequesterRequest != nil {
                        isShowingPendingRequestSheet = true
                    } else {
                        isShowingHelpSheet = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: pendingRequesterRequest == nil ? "location.fill" : "clock.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(pendingRequesterRequest == nil ? "Request Help" : "Pending Request")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.primaryBlueDark)
                    .padding(.vertical, 14)
                    .frame(maxWidth: 210)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(20)
        }
        .frame(height: 250)
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 12)
    }

    private var mapPreview: some View {
        ZStack(alignment: .bottomLeading) {
            Button {
                isShowingNearbyHelpersMap = true
            } label: {
                Map(coordinateRegion: $region)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
            }
            .buttonStyle(.plain)

            helpersNearbyOverlay
                .padding(12)
        }
    }

    private var requesterActiveTaskSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Task")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
            }

            if isLoadingActiveTask {
                ProgressView("Loading your active task...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            } else if let task = activeRequesterTask {
                VStack(alignment: .leading, spacing: 12) {
                    Text(task.request.serviceTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text("Helper: \(task.helperName)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(task.request.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)

                    if let requesterMessage {
                        Text(requesterMessage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryBlue)
                    }

                    Button {
                        markRequesterTaskCompleted(task)
                    } label: {
                        Text("Confirm Task Completion")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
                .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 10)
            } else {
                Text("No accepted task pending payment.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
            }
        }
    }

    private var helpersNearbyOverlay: some View {
        HStack(spacing: 10) {
            avatarStack

            Text("\(nearbyHelpersCount) Helpers Nearby")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)

            Spacer(minLength: 8)

            Circle()
                .fill(AppTheme.liveGreen)
                .frame(width: 8, height: 8)

            Text("Live")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 14, x: 0, y: 8)
    }

    private var avatarStack: some View {
        HStack(spacing: -10) {
            Circle()
                .fill(Color.orange.opacity(0.9))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "person.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                .overlay(Circle().stroke(Color.white, lineWidth: 2))

            Circle()
                .fill(Color.pink.opacity(0.9))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "person.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                .overlay(Circle().stroke(Color.white, lineWidth: 2))

            Circle()
                .fill(AppTheme.primaryBlue)
                .frame(width: 34, height: 28)
                .overlay(Text("+\(max(0, nearbyHelpersCount - 2))").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white, lineWidth: 2))
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(title: "YOUR SCORE", value: String(format: "%.1f", homeScore), suffix: "/5.0")
            statCard(title: "IMPACT", value: "\(homeImpactAssists)", suffix: "Assists")
        }
    }

    private func statCard(title: String, value: String, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(title == "IMPACT" ? Color.orange : AppTheme.primaryBlue)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(suffix)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))
        .shadow(color: AppTheme.shadow, radius: 18, x: 0, y: 10)
    }

    @MainActor
    private func loadNearbyHelpersCount() async {
        isLoadingHelpers = true
        defer { isLoadingHelpers = false }

        guard let location = locationManager.location else {
            nearbyHelpersCount = 0
            return
        }

        do {
            let helpers = try await HelpRequestService.shared.fetchNearbyHelpers(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radiusMeters: 5000
            )
            nearbyHelpersCount = helpers.count
        } catch {
            print("Error loading nearby helpers count: \(error.localizedDescription)")
            nearbyHelpersCount = 0
        }
    }

    @MainActor
    private func updateHelperStatus() async {
        do {
            try await HelpRequestService.shared.updateCurrentUserHelperEnabled(session.isHelperEnabled)
        } catch {
            print("Error syncing helper setting: \(error.localizedDescription)")
        }

        guard let location = locationManager.location else {
            if session.isHelperEnabled {
                await loadNearbyHelpersCount()
            } else {
                // Clear helper location when disabling helper mode
                do {
                    try await HelpRequestService.shared.deleteHelperLocation()
                    nearbyHelpersCount = 0
                } catch {
                    print("Error clearing helper location: \(error.localizedDescription)")
                }
            }
            return
        }

        if session.isHelperEnabled {
            // Update helper location when enabling
            do {
                try await HelpRequestService.shared.updateHelperLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                await loadNearbyHelpersCount()
            } catch {
                print("Error updating helper location: \(error.localizedDescription)")
                session.isHelperEnabled = false
            }
        } else {
            // Clear helper location when disabling
            do {
                try await HelpRequestService.shared.deleteHelperLocation()
                nearbyHelpersCount = 0
            } catch {
                print("Error clearing helper location: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func loadHelperStatusFromServer() async {
        do {
            if let settings = try await HelpRequestService.shared.fetchCurrentUserSettings() {
                session.isHelperEnabled = settings.isHelperEnabled
            }
        } catch {
            print("Error loading helper setting: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func loadActiveRequesterTask() async {
        isLoadingActiveTask = true
        defer { isLoadingActiveTask = false }
        do {
            let task = try await HelpRequestService.shared.fetchActiveRequesterTask()
            activeRequesterTask = task

            if let task {
                await LocalNotificationService.shared.notifyRequesterHelperAcceptedIfNeeded(
                    requestId: task.request.id,
                    helperName: task.helperName,
                    categoryTitle: task.request.serviceTitle
                )
            }
        } catch {
            activeRequesterTask = nil
            requesterMessage = "Unable to load active task: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadPendingRequesterRequest() async {
        do {
            pendingRequesterRequest = try await HelpRequestService.shared.fetchLatestPendingRequestForCurrentRequester()
        } catch {
            pendingRequesterRequest = nil
        }
    }

    private func markRequesterTaskCompleted(_ task: HelpRequestService.RequesterActiveTask) {
        Task {
            do {
                try await HelpRequestService.shared.markRequesterTaskCompleted(requestId: task.request.id)
                let refreshedTask = try await HelpRequestService.shared.fetchActiveRequesterTask()
                await MainActor.run {
                    activeRequesterTask = refreshedTask
                    if let refreshedTask, refreshedTask.acceptance.completedAt != nil {
                        paymentTask = refreshedTask
                        isShowingPaymentSheet = true
                        requesterMessage = nil
                    } else {
                        requesterMessage = "Marked completed. Waiting for helper completion to unlock payment."
                    }
                }
                await loadPendingRequesterRequest()
            } catch {
                await MainActor.run {
                    requesterMessage = "Unable to mark completion: \(error.localizedDescription)"
                }
            }
        }
    }

    @MainActor
    private func loadHomeStats() async {
        do {
            let stats = try await HelpRequestService.shared.fetchHomeHelperStats()
            homeScore = stats.averageScore
            homeImpactAssists = stats.impactAssists
        } catch {
            print("Error loading home helper stats: \(error.localizedDescription)")
            homeScore = 0
            homeImpactAssists = 0
        }
    }
}

private struct PendingRequestSheetView: View {
    let request: HelpRequest
    @Environment(\.dismiss) private var dismiss
    @State private var photoURLs: [String] = []
    @State private var isLoadingPhotos = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Pending Request")
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

                Text(request.serviceTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.primaryBlue)

                Text(request.description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Photos")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)

                    if isLoadingPhotos {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if photoURLs.isEmpty {
                        Text("No photos attached.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(photoURLs, id: \.self) { url in
                                    AsyncImage(url: URL(string: url)) { phase in
                                        switch phase {
                                        case let .success(image):
                                            image.resizable().scaledToFill()
                                        case .empty:
                                            ZStack {
                                                Color.black.opacity(0.04)
                                                ProgressView()
                                            }
                                        default:
                                            ZStack {
                                                Color.black.opacity(0.06)
                                                Image(systemName: "photo")
                                                    .foregroundStyle(AppTheme.textSecondary)
                                            }
                                        }
                                    }
                                    .frame(width: 112, height: 82)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }
                }

                HStack {
                    Text("Scope")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(request.scope == .helpZoneOnly ? "Zone Only" : "Zone + Global")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                HStack {
                    Text("Status")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(request.status == .accepted ? "Accepted (in progress)" : "Waiting for helper")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(request.status == .accepted ? AppTheme.categoryGreen : AppTheme.categoryOrange)
                }
            }
            .padding(20)
        }
        .background(AppTheme.screenBackground)
        .task {
            await loadPhotos()
        }
    }

    @MainActor
    private func loadPhotos() async {
        isLoadingPhotos = true
        defer { isLoadingPhotos = false }
        do {
            let photos = try await HelpRequestService.shared.fetchRequestPhotos(requestId: request.id)
            photoURLs = photos.map(\.photoUrl)
        } catch {
            photoURLs = []
        }
    }
}

enum HelpScope {
    case helpZoneOnly
    case helpZoneAndGlobal
}

private struct RequestPaymentSheetView: View {
    let task: HelpRequestService.RequesterActiveTask
    @Binding var isPresented: Bool

    @State private var vouchers: [DiscountVoucher] = []
    @State private var selectedVoucherId: UUID?
    @State private var isLoadingVouchers = false
    @State private var isPaying = false
    @State private var paymentMessage: String?

    private var selectedVoucher: DiscountVoucher? {
        vouchers.first(where: { $0.id == selectedVoucherId })
    }

    private var baseAmount: Double {
        switch task.request.category {
        case .technicalAndRepair: return 18
        case .physicalAndLogistics: return 15
        case .roadsideAndEmergency: return 20
        case .errandsAndSocial: return 12
        }
    }

    private var discountFraction: Double {
        Double(selectedVoucher?.discountPercent ?? 0) / 100
    }

    private var discountAmount: Double {
        baseAmount * discountFraction
    }

    private var finalAmount: Double {
        max(0, baseAmount - discountAmount)
    }

    var body: some View {
        ZStack {
            AppTheme.sheetBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Complete Payment")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Pay \(task.helperName) for the completed task")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Button {
                        isPresented = false
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

                VStack(alignment: .leading, spacing: 8) {
                    paymentRow(title: "Service fee", value: baseAmount)
                    paymentRow(title: "Discount", value: -discountAmount)
                    Divider()
                    paymentRow(title: "Total", value: finalAmount, isTotal: true)
                }
                .padding(16)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Apply Coupon")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    if isLoadingVouchers {
                        ProgressView()
                    } else if vouchers.isEmpty {
                        Text("No active discount coupons available.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(vouchers) { voucher in
                            Button {
                                selectedVoucherId = (selectedVoucherId == voucher.id) ? nil : voucher.id
                            } label: {
                                HStack {
                                    Image(systemName: selectedVoucherId == voucher.id ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedVoucherId == voucher.id ? AppTheme.primaryBlue : AppTheme.textSecondary)

                                    Text("\(voucher.discountPercent)% off (\(voucher.source.replacingOccurrences(of: "_", with: " ")))")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)

                                    Spacer()
                                }
                                .padding(12)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let paymentMessage {
                    Text(paymentMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Button {
                    completePayment()
                } label: {
                    if isPaying {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        Text("Pay $\(String(format: "%.2f", finalAmount))")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
                .buttonStyle(.plain)
                .disabled(isPaying)

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .task {
            await loadVouchers()
        }
    }

    private func paymentRow(title: String, value: Double, isTotal: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.system(size: isTotal ? 16 : 14, weight: isTotal ? .bold : .medium))
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text("$\(String(format: "%.2f", value))")
                .font(.system(size: isTotal ? 18 : 14, weight: .bold))
                .foregroundStyle(isTotal ? AppTheme.primaryBlue : AppTheme.textSecondary)
        }
    }

    private func loadVouchers() async {
        isLoadingVouchers = true
        defer { isLoadingVouchers = false }
        do {
            vouchers = try await HelpRequestService.shared.fetchAvailableDiscountVouchers(mode: .requester)
        } catch {
            paymentMessage = "Could not load vouchers: \(error.localizedDescription)"
        }
    }

    private func completePayment() {
        guard !isPaying else { return }
        isPaying = true
        paymentMessage = nil

        Task {
            do {
                try await HelpRequestService.shared.completePayment(
                    requestId: task.request.id,
                    selectedVoucher: selectedVoucher
                )
                await MainActor.run {
                    paymentMessage = "Payment completed successfully."
                }
                try? await Task.sleep(nanoseconds: 800_000_000)
                await MainActor.run {
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    paymentMessage = "Payment failed: \(error.localizedDescription)"
                }
            }
            await MainActor.run {
                isPaying = false
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppSession())
}
