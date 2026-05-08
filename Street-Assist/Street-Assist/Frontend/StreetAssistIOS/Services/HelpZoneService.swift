import Foundation
import Supabase
import UIKit

final class HelpZoneService {
    static let shared = HelpZoneService()
    private init() {}

    struct ZoneMemberProfile: Identifiable {
        let id: UUID
        let fullName: String
        let role: ZoneRole
        let joinedAt: Date
        let isHelperEnabled: Bool
    }

    func generateJoinCode(prefix: String = "ZONE") -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let suffix = String((0..<5).map { _ in letters.randomElement()! })
        return "\(prefix)-\(suffix)"
    }

    func createZone(zoneName: String, organizationName: String, idDocument: UIImage?) async throws -> HelpZone {
        let documentData = idDocument?.jpegData(compressionQuality: 0.8)
        return try await createZone(
            zoneName: zoneName,
            organizationName: organizationName,
            idDocumentData: documentData,
            idDocumentContentType: documentData == nil ? nil : "image/jpeg",
            idDocumentFileExtension: documentData == nil ? nil : "jpg"
        )
    }

    func createZone(
        zoneName: String,
        organizationName: String,
        idDocumentData: Data?,
        idDocumentContentType: String?,
        idDocumentFileExtension: String?
    ) async throws -> HelpZone {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "HelpZoneService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let joinCode = generateJoinCode(prefix: zoneName.components(separatedBy: " ").first?.uppercased() ?? "ZONE")

        var data: [String: AnyJSON] = [
            "zone_name": .string(zoneName),
            "organization_name": .string(organizationName),
            "join_code": .string(joinCode),
            "created_by_user_id": .string(userId.uuidString)
        ]

        let response: HelpZone = try await SupabaseManager.shared.client
            .from("help_zones")
            .insert(data)
            .select()
            .single()
            .execute()
            .value

        // Upload document and create verification submission if document is provided
        if let idDocumentData,
           let idDocumentContentType,
           let idDocumentFileExtension {
            let documentUrl = try await StorageService.shared.uploadZoneDocument(
                data: idDocumentData,
                fileName: "zone_\(response.id.uuidString)_verification",
                contentType: idDocumentContentType,
                fileExtension: idDocumentFileExtension
            )

            let submissionData: [String: AnyJSON] = [
                "zone_id": .string(response.id.uuidString),
                "submitted_by_user_id": .string(userId.uuidString),
                "document_url": .string(documentUrl),
                "status": .string("pending")
            ]

            _ = try await SupabaseManager.shared.client
                .from("help_zone_verification_submissions")
                .insert(submissionData)
                .execute()
        }

        return response
    }

    func joinZone(joinCode: String) async throws -> ZoneMembership {
        // lookup zone by join_code
        let zones: [HelpZone] = try await SupabaseManager.shared.client
            .from("help_zones")
            .select()
            .eq("join_code", value: joinCode)
            .limit(1)
            .execute()
            .value

        guard let zone = zones.first else {
            throw NSError(domain: "HelpZoneService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Zone not found"])
        }

        // Prevent joining zones that are not approved
        if zone.verificationStatus != .approved {
            throw NSError(domain: "HelpZoneService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Cannot join this zone — verification pending or rejected."])
        }

        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            throw NSError(domain: "HelpZoneService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        let data: [String: AnyJSON] = [
            "zone_id": .string(zone.id.uuidString),
            "user_id": .string(userId.uuidString),
            "role": .string("member"),
            "status": .string("active")
        ]

        let response: ZoneMembership = try await SupabaseManager.shared.client
            .from("zone_memberships")
            .insert(data)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    func fetchJoinedZones() async throws -> [HelpZone] {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return []
        }

        let memberships: [ZoneMembership] = try await SupabaseManager.shared.client
            .from("zone_memberships")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: ZoneMemberStatus.active.rawValue)
            .execute()
            .value

        let zoneIds = memberships.map { $0.zoneId.uuidString }
        guard !zoneIds.isEmpty else { return [] }

        let zones: [HelpZone] = try await SupabaseManager.shared.client
            .from("help_zones")
            .select()
            .in("id", values: zoneIds)
            .eq("verification_status", value: "approved")
            .execute()
            .value

        return zones
    }

    func fetchJoinedZoneIDsForCurrentUser() async throws -> Set<UUID> {
        guard let userId = SupabaseManager.shared.client.auth.currentUser?.id
            ?? SupabaseManager.shared.client.auth.currentSession?.user.id else {
            return []
        }

        let memberships: [ZoneMembership] = try await SupabaseManager.shared.client
            .from("zone_memberships")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("status", value: ZoneMemberStatus.active.rawValue)
            .execute()
            .value

        return Set(memberships.map(\.zoneId))
    }

    func fetchZoneMembers(zoneId: UUID) async throws -> [ZoneMemberProfile] {
        struct UserNameRow: Decodable {
            let id: UUID
            let fullName: String

            enum CodingKeys: String, CodingKey {
                case id
                case fullName = "full_name"
            }
        }

        let memberships: [ZoneMembership] = try await SupabaseManager.shared.client
            .from("zone_memberships")
            .select()
            .eq("zone_id", value: zoneId.uuidString)
            .eq("status", value: ZoneMemberStatus.active.rawValue)
            .order("joined_at", ascending: true)
            .execute()
            .value

        let userIDs = memberships.map(\.userId)
        guard !userIDs.isEmpty else {
            return []
        }

        let users: [UserNameRow] = try await SupabaseManager.shared.client
            .from("users")
            .select("id, full_name")
            .in("id", values: userIDs.map(\.uuidString))
            .execute()
            .value

        let settings: [UserSettings] = try await SupabaseManager.shared.client
            .from("user_settings")
            .select()
            .in("user_id", values: userIDs.map(\.uuidString))
            .execute()
            .value

        let nameByUserID = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0.fullName) })
        let helperEnabledByUserID = Dictionary(uniqueKeysWithValues: settings.map { ($0.userId, $0.isHelperEnabled) })

        return memberships.map { membership in
            ZoneMemberProfile(
                id: membership.userId,
                fullName: nameByUserID[membership.userId] ?? "Member",
                role: membership.role,
                joinedAt: membership.joinedAt,
                isHelperEnabled: helperEnabledByUserID[membership.userId] ?? false
            )
        }
    }

    func fetchZoneOnlyRequests(zoneId: UUID) async throws -> [HelpRequest] {
        let response: [HelpRequest] = try await SupabaseManager.shared.client
            .from("help_requests")
            .select()
            .eq("zone_id", value: zoneId.uuidString)
            .eq("scope", value: RequestScope.helpZoneOnly.rawValue)
            .eq("status", value: RequestStatus.open.rawValue)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response
    }
}
