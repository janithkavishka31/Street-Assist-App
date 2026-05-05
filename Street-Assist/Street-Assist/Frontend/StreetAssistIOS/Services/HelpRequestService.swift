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

    func fetchNearbyHelpers(
        latitude: Double,
        longitude: Double,
        radiusMeters: CLLocationDistance = 5000
    ) async throws -> [HelperLocation] {
        let radiusKm = radiusMeters / 1000.0

        let response: [HelperLocation] = try await SupabaseManager.shared.client
            .from("helper_locations")
            .select()
            .execute()
            .value

        let userLocation = CLLocation(latitude: latitude, longitude: longitude)
        let filtered = response.filter { helper in
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

        let response: HelpRequestAcceptance = try await SupabaseManager.shared.client
            .from("help_request_acceptances")
            .insert(data)
            .select()
            .single()
            .execute()
            .value

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
            .limit(1)
            .execute()
            .value

        guard let request = requests.first else {
            return nil
        }

        let acceptances: [HelpRequestAcceptance] = try await SupabaseManager.shared.client
            .from("help_request_acceptances")
            .select()
            .eq("request_id", value: request.id.uuidString)
            .limit(1)
            .execute()
            .value

        guard let acceptance = acceptances.first else {
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
}
