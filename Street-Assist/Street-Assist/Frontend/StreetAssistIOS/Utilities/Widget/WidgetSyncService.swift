import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetSyncService {
    // NOTE: Set this same App Group on both app + widget targets in Signing & Capabilities.
    static let appGroupSuite = "group.streetassist"

    private enum Key {
        static let totalPoints = "widget.total_points"
        static let streakDays = "widget.streak_days"
        static let mode = "widget.mode"
        static let updatedAt = "widget.updated_at"
    }

    static func saveSnapshot(totalPoints: Int, streakDays: Int, modeRawValue: String) {
        guard let defaults = UserDefaults(suiteName: appGroupSuite) else { return }

        defaults.set(totalPoints, forKey: Key.totalPoints)
        defaults.set(streakDays, forKey: Key.streakDays)
        defaults.set(modeRawValue, forKey: Key.mode)
        defaults.set(Date().timeIntervalSince1970, forKey: Key.updatedAt)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "street_assist")
        WidgetCenter.shared.reloadTimelines(ofKind: "Street_Assist_Pulse")
        #endif
    }
}

