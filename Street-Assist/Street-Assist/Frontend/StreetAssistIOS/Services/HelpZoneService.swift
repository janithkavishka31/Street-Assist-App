import Foundation
import Supabase

final class HelpZoneService {
    static let shared = HelpZoneService()
    private init() {}

    func generateJoinCode(prefix: String = "ZONE") -> String {
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let suffix = String((0..<5).map { _ in letters.randomElement()! })
        return "\(prefix)-\(suffix)"
    }

    func createZone(zoneName: String, organizationName: String, idDocumentUrl: String? = nil) async throws -> HelpZone {
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
            .execute()
            .value

        return zones
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
