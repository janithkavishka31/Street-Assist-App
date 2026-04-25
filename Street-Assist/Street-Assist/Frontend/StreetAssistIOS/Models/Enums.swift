import Foundation

enum VerificationStatus: String, Codable {
    case pending, approved, rejected
}

enum HelpCategory: String, Codable {
    case technicalAndRepair = "technicalAndRepair"
    case physicalAndLogistics = "physicalAndLogistics"
    case roadsideAndEmergency = "roadsideAndEmergency"
    case errandsAndSocial = "errandsAndSocial"
}

enum RequestScope: String, Codable {
    case helpZoneOnly = "help_zone_only"
    case helpZoneAndGlobal = "help_zone_and_global"
}

enum RequestStatus: String, Codable {
    case open, accepted, completed, canceled
}

enum ZoneRole: String, Codable {
    case creator, member
}

enum ZoneMemberStatus: String, Codable {
    case active, left, banned
}

enum PointsReason: String, Codable {
    case assistCompleted = "assist_completed"
    case bonus, adjustment
}

enum LeaderboardMode: String, Codable {
    case helper, requester
}

enum SkillKey: String, Codable {
    case technical, physical, roadside, errands
}