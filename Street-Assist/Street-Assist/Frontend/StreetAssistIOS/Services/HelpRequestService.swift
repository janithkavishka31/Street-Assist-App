import CoreLocation
import Foundation
import Supabase
import UIKit

class HelpRequestService {
    static let shared = HelpRequestService()

    private init() {}

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
}