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
}