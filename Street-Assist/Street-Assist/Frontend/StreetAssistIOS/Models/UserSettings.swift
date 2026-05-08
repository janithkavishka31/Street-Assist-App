import Foundation

struct UserSettings: Codable {
    let userId: UUID
    let isHelperEnabled: Bool
    let defaultScope: RequestScope
    let isScreenReaderEnabled: Bool
    let isSoundEffectsEnabled: Bool
    let isDynamicTextEnabled: Bool
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isHelperEnabled = "is_helper_enabled"
        case defaultScope = "default_scope"
        case isScreenReaderEnabled = "is_screen_reader_enabled"
        case isSoundEffectsEnabled = "is_sound_effects_enabled"
        case isDynamicTextEnabled = "is_dynamic_text_enabled"
        case updatedAt = "updated_at"
    }

    init(
        userId: UUID,
        isHelperEnabled: Bool,
        defaultScope: RequestScope,
        isScreenReaderEnabled: Bool,
        isSoundEffectsEnabled: Bool,
        isDynamicTextEnabled: Bool,
        updatedAt: Date
    ) {
        self.userId = userId
        self.isHelperEnabled = isHelperEnabled
        self.defaultScope = defaultScope
        self.isScreenReaderEnabled = isScreenReaderEnabled
        self.isSoundEffectsEnabled = isSoundEffectsEnabled
        self.isDynamicTextEnabled = isDynamicTextEnabled
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        isHelperEnabled = try container.decode(Bool.self, forKey: .isHelperEnabled)
        defaultScope = try container.decode(RequestScope.self, forKey: .defaultScope)
        isScreenReaderEnabled = try container.decodeIfPresent(Bool.self, forKey: .isScreenReaderEnabled) ?? false
        isSoundEffectsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEffectsEnabled) ?? true
        isDynamicTextEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDynamicTextEnabled) ?? true
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}