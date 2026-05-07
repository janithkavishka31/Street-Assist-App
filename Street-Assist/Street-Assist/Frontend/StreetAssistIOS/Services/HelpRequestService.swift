import CoreLocation
import Foundation
import Supabase
import UIKit

class HelpRequestService {
    static let shared = HelpRequestService()

    private init() {}

    struct RequesterActiveTask {
        let request: HelpRequest
        let acceptance: HelpRequestAcceptance
        let helperName: String
    }

    struct HelperDashboardStats {
        let totalPoints: Int
        let todayPoints: Int
        let weeklyAssists: Int
        let currentStreakDays: Int
    }

    struct HomeHelperStats {
        let averageScore: Double
        let impactAssists: Int
    }

    struct UserProfileSummary {
        let user: User
        let settings: UserSettings?
        let skillTitles: [String]
        let selectedSkillIDs: Set<Int>
        let totalPoints: Int
        let weeklyAssists: Int
        let currentStreakDays: Int
        let bestStreakDays: Int
    }

    struct UserProfileUpdatePayload {
        let fullName: String
        let phone: String?
        let quickBio: String?
        let isHelperEnabled: Bool
        let defaultScope: RequestScope
        let selectedSkillIDs: Set<Int>
    }

    struct RequesterPreview: Decodable {
        let fullName: String
        let phone: String?
        let quickBio: String?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
            case phone
            case quickBio = "quick_bio"
        }
    }

    func createRequest(
        category: HelpCategory,
        description: String,
        latitude: Double,
        longitude: Double,
        scope: RequestScope,
        zoneId: UUID?,
        photos: [UIImage]
    ) async throws -> HelpRequest {
        // Get current user ID
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "HelpRequestService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Insert help request
        var requestData: [String: AnyJSON] = [
            "requester_user_id": .string(userId.uuidString),
            "category": .string(category.rawValue),
            "service_title": .string(serviceTitle(for: category)),
            "description": .string(description),
            "latitude": .double(latitude),
            "longitude": .double(longitude),
            "scope": .string(scope.rawValue),
            "status": .string(RequestStatus.open.rawValue)
        ]

        requestData["zone_id"] = zoneId.map { .string($0.uuidString) } ?? .null

        let response: HelpRequest = try await SupabaseManager.shared.client
            .from("help_requests")
            .insert(requestData)
            .select()
            .single()
            .execute()
            .value

        // Upload photos and save URLs
        if !photos.isEmpty {
            var photoRecords: [[String: AnyJSON]] = []
            for (index, photo) in photos.enumerated() {
                let url = try await StorageService.shared.uploadImage(photo, fileName: "photo_\(index)")
                photoRecords.append([
                    "request_id": .string(response.id.uuidString),
                    "photo_url": .string(url),
                    "sort_order": .integer(index)
                ])
            }

            _ = try await SupabaseManager.shared.client
                .from("help_request_photos")
                .insert(photoRecords)
                .execute()
        }

        return response
    }

    private func serviceTitle(for category: HelpCategory) -> String {
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

    func fetchOpenRequests() async throws -> [HelpRequest] {
        let response: [HelpRequest] = try await SupabaseManager.shared.client
            .from("help_requests")
            .select()
            .eq("status", value: RequestStatus.open.rawValue)
            .execute()
            .value

        return response
    }

    func fetchRequestPhotos(requestId: UUID) async throws -> [HelpRequestPhoto] {
        let response: [HelpRequestPhoto] = try await SupabaseManager.shared.client
            .from("help_request_photos")
            .select()
            .eq("request_id", value: requestId.uuidString)
            .order("sort_order")
            .execute()
            .value

        return response
    }

    func fetchRequesterPreview(userId: UUID) async throws -> RequesterPreview? {
        let rows: [RequesterPreview] = try await SupabaseManager.shared.client
            .from("users")
            .select("full_name, phone, quick_bio")
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return rows.first
    }

    func fetchCurrentUserSkillKeys() async throws -> Set<SkillKey> {
        let auth = SupabaseManager.shared.client.auth
        let metadata = auth.currentUser?.userMetadata ?? auth.currentSession?.user.userMetadata

        if let metadata, let keys = skillKeys(from: metadata), !keys.isEmpty {
            return keys
        }

        guard let userId = auth.currentUser?.id ?? auth.currentSession?.user.id else {
            return []
        }

        let userSkills: [UserSkill] = try await SupabaseManager.shared.client
            .from("user_skills")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let skillIds = userSkills.map { $0.skillId }
        guard !skillIds.isEmpty else {
            return []
        }

        let skills: [Skill] = try await SupabaseManager.shared.client
            .from("skills")
            .select()
            .in("id", values: skillIds)
            .execute()
            .value

        return Set(skills.map { $0.key })
    }

    private func skillKeys(from metadata: [String: AnyJSON]) -> Set<SkillKey>? {
        guard let skillsValue = metadata["skills"], case let .array(values) = skillsValue else {
            return nil
        }

        let keys = values.compactMap { value -> SkillKey? in
            guard case let .string(raw) = value else { return nil }
            return SkillKey(rawValue: raw)
        }

        return Set(keys)
    }

    func fetchCurrentUserSettings() async throws -> UserSettings? {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return nil
        }

        let settings: [UserSettings] = try await SupabaseManager.shared.client
            .from("user_settings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        return settings.first
    }

    func updateCurrentUserHelperEnabled(_ isEnabled: Bool) async throws {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "HelpRequestService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let data: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "is_helper_enabled": .bool(isEnabled),
            "updated_at": .string(Date().ISO8601Format())
        ]

        _ = try await SupabaseManager.shared.client
            .from("user_settings")
            .upsert(data)
            .execute()
    }

    func fetchNearbyHelpers(
        latitude: Double,
        longitude: Double,
        radiusMeters: CLLocationDistance = 5000
    ) async throws -> [HelperLocation] {
        let response: [HelperLocation] = try await SupabaseManager.shared.client
            .from("helper_locations")
            .select()
            .execute()
            .value

        let currentUserId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id

        // Keep only the latest location per helper user to avoid duplicate markers/counts.
        let latestByUser = Dictionary(
            response
                .filter { currentUserId == nil || $0.userId != currentUserId }
                .sorted { $0.updatedAt > $1.updatedAt }
                .map { ($0.userId, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let userLocation = CLLocation(latitude: latitude, longitude: longitude)
        let filtered = latestByUser.values.filter { helper in
            let helperLocation = CLLocation(latitude: helper.latitude, longitude: helper.longitude)
            let distance = userLocation.distance(from: helperLocation)
            return distance <= radiusMeters
        }

        return filtered
    }

    func updateHelperLocation(latitude: Double, longitude: Double) async throws {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "HelpRequestService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let data: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "latitude": .double(latitude),
            "longitude": .double(longitude),
            "updated_at": .string(Date().ISO8601Format())
        ]

        _ = try await SupabaseManager.shared.client
            .from("helper_locations")
            .upsert(data)
            .execute()
    }

    func deleteHelperLocation() async throws {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "HelpRequestService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        _ = try await SupabaseManager.shared.client
            .from("helper_locations")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func acceptRequest(requestId: UUID) async throws -> HelpRequestAcceptance {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "HelpRequestService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let data: [String: AnyJSON] = [
            "request_id": .string(requestId.uuidString),
            "helper_user_id": .string(userId.uuidString),
            "accepted_at": .string(Date().ISO8601Format())
        ]

        let response: HelpRequestAcceptance
        do {
            response = try await SupabaseManager.shared.client
                .from("help_request_acceptances")
                .insert(data)
                .select()
                .single()
                .execute()
                .value
        } catch {
            if isAlreadyAcceptedError(error) {
                throw NSError(
                    domain: "HelpRequestService",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "This request has already been accepted by another helper."]
                )
            }
            throw error
        }

        let requestUpdate: [String: AnyJSON] = [
            "status": .string(RequestStatus.accepted.rawValue),
            "updated_at": .string(Date().ISO8601Format())
        ]

        _ = try await SupabaseManager.shared.client
            .from("help_requests")
            .update(requestUpdate)
            .eq("id", value: requestId.uuidString)
            .execute()

        return response
    }

    func isRequestAcceptedByCurrentUser(requestId: UUID) async throws -> Bool {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return false
        }

        let response: [HelpRequestAcceptance] = try await SupabaseManager.shared.client
            .from("help_request_acceptances")
            .select()
            .eq("request_id", value: requestId.uuidString)
            .eq("helper_user_id", value: userId.uuidString)
            .execute()
            .value

        return !response.isEmpty
    }

    func getAcceptanceForRequest(requestId: UUID) async throws -> HelpRequestAcceptance? {
        let response: [HelpRequestAcceptance] = try await SupabaseManager.shared.client
            .from("help_request_acceptances")
            .select()
            .eq("request_id", value: requestId.uuidString)
            .execute()
            .value

        return response.first
    }

    func fetchAcceptancesForCurrentUser() async throws -> [HelpRequestAcceptance] {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return []
        }

        let response: [HelpRequestAcceptance] = try await SupabaseManager.shared.client
            .from("help_request_acceptances")
            .select()
            .eq("helper_user_id", value: userId.uuidString)
            .execute()
            .value

        return response
    }

    func fetchAcceptedRequestsForCurrentHelper() async throws -> [HelpRequest] {
        let acceptances = try await fetchAcceptancesForCurrentUser()
        let requestIds = acceptances.map(\.requestId.uuidString)
        guard !requestIds.isEmpty else {
            return []
        }

        let requests: [HelpRequest] = try await SupabaseManager.shared.client
            .from("help_requests")
            .select()
            .in("id", values: requestIds)
            .in("status", values: [RequestStatus.accepted.rawValue, RequestStatus.open.rawValue])
            .execute()
            .value

        return requests
    }

    func markHelperTaskCompleted(requestId: UUID) async throws {
        let completionData: [String: AnyJSON] = [
            "completed_at": .string(Date().ISO8601Format())
        ]

        _ = try await SupabaseManager.shared.client
            .from("help_request_acceptances")
            .update(completionData)
            .eq("request_id", value: requestId.uuidString)
            .execute()
    }

    func markRequesterTaskCompleted(requestId: UUID) async throws {
        let completionData: [String: AnyJSON] = [
            "requester_completed_at": .string(Date().ISO8601Format())
        ]

        _ = try await SupabaseManager.shared.client
            .from("help_requests")
            .update(completionData)
            .eq("id", value: requestId.uuidString)
            .execute()
    }

    func fetchActiveRequesterTask() async throws -> RequesterActiveTask? {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return nil
        }

        let requests: [HelpRequest] = try await SupabaseManager.shared.client
            .from("help_requests")
            .select()
            .eq("requester_user_id", value: userId.uuidString)
            .in("status", values: [RequestStatus.open.rawValue, RequestStatus.accepted.rawValue])
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value

        guard !requests.isEmpty else {
            return nil
        }

        let requestIDStrings = requests.map { $0.id.uuidString }
        let acceptances: [HelpRequestAcceptance] = try await SupabaseManager.shared.client
            .from("help_request_acceptances")
            .select()
            .in("request_id", values: requestIDStrings)
            .execute()
            .value

        let acceptanceByRequestID = Dictionary(uniqueKeysWithValues: acceptances.map { ($0.requestId, $0) })
        guard let request = requests.first(where: { acceptanceByRequestID[$0.id] != nil }),
              let acceptance = acceptanceByRequestID[request.id] else {
            return nil
        }

        struct UserNameRow: Decodable {
            let fullName: String
            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
            }
        }

        let users: [UserNameRow] = try await SupabaseManager.shared.client
            .from("users")
            .select("full_name")
            .eq("id", value: acceptance.helperUserId.uuidString)
            .limit(1)
            .execute()
            .value

        return RequesterActiveTask(
            request: request,
            acceptance: acceptance,
            helperName: users.first?.fullName ?? "Your helper"
        )
    }

    func fetchLatestPendingRequestForCurrentRequester() async throws -> HelpRequest? {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return nil
        }

        let requests: [HelpRequest] = try await SupabaseManager.shared.client
            .from("help_requests")
            .select()
            .eq("requester_user_id", value: userId.uuidString)
            .in("status", values: [RequestStatus.open.rawValue, RequestStatus.accepted.rawValue])
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value

        return requests.first
    }

    private func isAlreadyAcceptedError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("duplicate key")
            || message.contains("violates unique constraint")
            || message.contains("help_request_acceptances_request_id_key")
    }

    func fetchAvailableDiscountVouchers(mode: LeaderboardMode) async throws -> [DiscountVoucher] {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return []
        }

        return try await SupabaseManager.shared.client
            .from("discount_vouchers")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("mode", value: mode.rawValue)
            .eq("is_used", value: false)
            .gt("valid_until", value: Date().ISO8601Format())
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func completePayment(
        requestId: UUID,
        selectedVoucher: DiscountVoucher?
    ) async throws {
        let requests: [HelpRequest] = try await SupabaseManager.shared.client
            .from("help_requests")
            .select()
            .eq("id", value: requestId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let request = requests.first else {
            throw NSError(domain: "HelpRequestService", code: 100, userInfo: [NSLocalizedDescriptionKey: "Request not found"])
        }

        let acceptances: [HelpRequestAcceptance] = try await SupabaseManager.shared.client
            .from("help_request_acceptances")
            .select()
            .eq("request_id", value: requestId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let acceptance = acceptances.first else {
            throw NSError(domain: "HelpRequestService", code: 101, userInfo: [NSLocalizedDescriptionKey: "No helper accepted this request yet"])
        }

        guard acceptance.completedAt != nil, request.requesterCompletedAt != nil else {
            throw NSError(domain: "HelpRequestService", code: 102, userInfo: [NSLocalizedDescriptionKey: "Both requester and helper must complete the task first"])
        }

        guard request.status != .completed else {
            return
        }

        let baseAmount: Double
        switch request.category {
        case .technicalAndRepair: baseAmount = 18
        case .physicalAndLogistics: baseAmount = 15
        case .roadsideAndEmergency: baseAmount = 20
        case .errandsAndSocial: baseAmount = 12
        }

        let discount = Double(selectedVoucher?.discountPercent ?? 0) / 100
        let finalAmount = max(0, baseAmount - (baseAmount * discount))

        if let voucher = selectedVoucher {
            let voucherUpdate: [String: AnyJSON] = [
                "is_used": .bool(true),
                "request_id": .string(requestId.uuidString)
            ]

            _ = try await SupabaseManager.shared.client
                .from("discount_vouchers")
                .update(voucherUpdate)
                .eq("id", value: voucher.id.uuidString)
                .execute()
        }

        let requestUpdate: [String: AnyJSON] = [
            "status": .string(RequestStatus.completed.rawValue),
            "payment_completed_at": .string(Date().ISO8601Format()),
            "paid_amount": .double(finalAmount),
            "updated_at": .string(Date().ISO8601Format())
        ]

        _ = try await SupabaseManager.shared.client
            .from("help_requests")
            .update(requestUpdate)
            .eq("id", value: requestId.uuidString)
            .execute()

        try await RankingsService.shared.recordPaymentCompletion(
            requestId: requestId,
            helperUserId: acceptance.helperUserId,
            requesterUserId: request.requesterUserId
        )
    }

    func fetchHelperDashboardStats() async throws -> HelperDashboardStats {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return HelperDashboardStats(totalPoints: 0, todayPoints: 0, weeklyAssists: 0, currentStreakDays: 0)
        }

        struct GamificationRow: Decodable {
            let totalPoints: Int
            enum CodingKeys: String, CodingKey {
                case totalPoints = "total_points"
            }
        }

        struct PointsRow: Decodable {
            let points: Int
        }

        let gamificationRows: [GamificationRow] = try await SupabaseManager.shared.client
            .from("user_gamification")
            .select("total_points")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let startOfWeek = startOfCurrentWeekSunday(from: now)
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek) ?? now

        let todayPointsRows: [PointsRow] = try await SupabaseManager.shared.client
            .from("points_ledger")
            .select("points")
            .eq("user_id", value: userId.uuidString)
            .gte("created_at", value: startOfToday.ISO8601Format())
            .lt("created_at", value: startOfTomorrow.ISO8601Format())
            .execute()
            .value

        let weeklyAcceptances: [HelpRequestAcceptance] = try await SupabaseManager.shared.client
            .from("help_request_acceptances")
            .select()
            .eq("helper_user_id", value: userId.uuidString)
            .gte("completed_at", value: startOfWeek.ISO8601Format())
            .lt("completed_at", value: endOfWeek.ISO8601Format())
            .execute()
            .value

        let streakRows: [UserModeStreak] = try await SupabaseManager.shared.client
            .from("user_mode_streaks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("mode", value: LeaderboardMode.helper.rawValue)
            .limit(1)
            .execute()
            .value

        return HelperDashboardStats(
            totalPoints: gamificationRows.first?.totalPoints ?? 0,
            todayPoints: todayPointsRows.reduce(0) { $0 + $1.points },
            weeklyAssists: weeklyAcceptances.count,
            currentStreakDays: streakRows.first?.currentStreakDays ?? 0
        )
    }

    func fetchHomeHelperStats() async throws -> HomeHelperStats {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return HomeHelperStats(averageScore: 0, impactAssists: 0)
        }

        let ratings: [HelpRequestRating] = try await SupabaseManager.shared.client
            .from("help_request_ratings")
            .select()
            .eq("rated_user_id", value: userId.uuidString)
            .execute()
            .value

        let completedAcceptances: [HelpRequestAcceptance] = try await SupabaseManager.shared.client
            .from("help_request_acceptances")
            .select()
            .eq("helper_user_id", value: userId.uuidString)
            .not("completed_at", operator: .is, value: "null")
            .execute()
            .value

        let averageScore: Double
        if ratings.isEmpty {
            averageScore = 0
        } else {
            averageScore = Double(ratings.reduce(0) { $0 + $1.score }) / Double(ratings.count)
        }

        return HomeHelperStats(
            averageScore: averageScore,
            impactAssists: completedAcceptances.count
        )
    }

    func fetchCurrentUserProfileSummary() async throws -> UserProfileSummary {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "HelpRequestService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let users: [User] = try await SupabaseManager.shared.client
            .from("users")
            .select()
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let user = users.first else {
            throw NSError(domain: "HelpRequestService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }

        let settingsRows: [UserSettings] = try await SupabaseManager.shared.client
            .from("user_settings")
            .select()
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        let userSkills: [UserSkill] = try await SupabaseManager.shared.client
            .from("user_skills")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let skillIds = userSkills.map(\.skillId)
        let skills: [Skill]
        if skillIds.isEmpty {
            skills = []
        } else {
            skills = try await SupabaseManager.shared.client
                .from("skills")
                .select()
                .in("id", values: skillIds)
                .execute()
                .value
        }

        struct GamificationRow: Decodable {
            let totalPoints: Int
            let weeklyAssists: Int
            let currentStreakDays: Int
            let bestStreakDays: Int

            enum CodingKeys: String, CodingKey {
                case totalPoints = "total_points"
                case weeklyAssists = "weekly_assists"
                case currentStreakDays = "current_streak_days"
                case bestStreakDays = "best_streak_days"
            }
        }

        let gamificationRows: [GamificationRow] = try await SupabaseManager.shared.client
            .from("user_gamification")
            .select("total_points, weekly_assists, current_streak_days, best_streak_days")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        let gamification = gamificationRows.first

        return UserProfileSummary(
            user: user,
            settings: settingsRows.first,
            skillTitles: skills.map(\.title).sorted(),
            selectedSkillIDs: Set(skills.map(\.id)),
            totalPoints: gamification?.totalPoints ?? 0,
            weeklyAssists: gamification?.weeklyAssists ?? 0,
            currentStreakDays: gamification?.currentStreakDays ?? 0,
            bestStreakDays: gamification?.bestStreakDays ?? 0
        )
    }

    func fetchAllSkills() async throws -> [Skill] {
        let skills: [Skill] = try await SupabaseManager.shared.client
            .from("skills")
            .select()
            .order("id", ascending: true)
            .execute()
            .value
        return skills
    }

    func updateCurrentUserProfile(payload: UserProfileUpdatePayload) async throws {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "HelpRequestService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let trimmedFullName = payload.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFullName.isEmpty else {
            throw NSError(domain: "HelpRequestService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Full name cannot be empty"])
        }

        let trimmedPhone = payload.phone?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = payload.quickBio?.trimmingCharacters(in: .whitespacesAndNewlines)

        var userData: [String: AnyJSON] = [
            "full_name": .string(trimmedFullName),
            "updated_at": .string(Date().ISO8601Format())
        ]

        userData["phone"] = (trimmedPhone?.isEmpty == false) ? .string(trimmedPhone!) : .null
        userData["quick_bio"] = (trimmedBio?.isEmpty == false) ? .string(trimmedBio!) : .null

        _ = try await SupabaseManager.shared.client
            .from("users")
            .update(userData)
            .eq("id", value: userId.uuidString)
            .execute()

        let settingsData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "is_helper_enabled": .bool(payload.isHelperEnabled),
            "default_scope": .string(payload.defaultScope.rawValue),
            "updated_at": .string(Date().ISO8601Format())
        ]

        _ = try await SupabaseManager.shared.client
            .from("user_settings")
            .upsert(settingsData)
            .execute()

        _ = try await SupabaseManager.shared.client
            .from("user_skills")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .execute()

        if !payload.selectedSkillIDs.isEmpty {
            let skillRows: [[String: AnyJSON]] = payload.selectedSkillIDs.sorted().map { skillID in
                [
                    "user_id": .string(userId.uuidString),
                    "skill_id": .integer(skillID)
                ]
            }

            _ = try await SupabaseManager.shared.client
                .from("user_skills")
                .insert(skillRows)
                .execute()
        }
    }

    private func startOfCurrentWeekSunday(from date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let shifted = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: shifted)
        let mondayStart = calendar.date(from: components) ?? date
        return calendar.date(byAdding: .day, value: -1, to: mondayStart) ?? mondayStart
    }
}
