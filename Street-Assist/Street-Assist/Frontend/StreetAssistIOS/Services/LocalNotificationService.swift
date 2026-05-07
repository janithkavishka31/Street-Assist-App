import Foundation
import Supabase
import UserNotifications

final class LocalNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationDelegate()

    private override init() {}

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banners even when app is in foreground (important for simulator testing).
        completionHandler([.banner, .list, .sound])
    }
}

final class LocalNotificationService {
    static let shared = LocalNotificationService()

    private enum Key {
        static let notifiedEventIDsPrefix = "local_notifications.notified_event_ids"
    }

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return
        }

        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification auth request failed: \(error.localizedDescription)")
        }
    }

    func notifyNewRequestIfNeeded(
        requestId: UUID,
        title: String,
        body: String
    ) async {
        guard await notificationsAllowed else {
            return
        }

        let eventID = "new_request:\(requestId.uuidString)"
        let dedupeKey = notifiedEventIDsKeyForCurrentUser()
        var notifiedIDs = notifiedEventIDs(for: dedupeKey)
        guard !notifiedIDs.contains(eventID) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streetassist.request.\(requestId.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            notifiedIDs.insert(eventID)
            setNotifiedEventIDs(notifiedIDs, for: dedupeKey)
        } catch {
            print("Failed to schedule local notification: \(error.localizedDescription)")
        }
    }

    func notifyRequesterHelperAcceptedIfNeeded(
        requestId: UUID,
        helperName: String,
        categoryTitle: String
    ) async {
        guard await notificationsAllowed else {
            return
        }

        let eventID = "request_accepted:\(requestId.uuidString)"
        let dedupeKey = notifiedEventIDsKeyForCurrentUser()
        var notifiedIDs = notifiedEventIDs(for: dedupeKey)
        guard !notifiedIDs.contains(eventID) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Helper accepted your request"
        content.body = "\(helperName) accepted your \(categoryTitle) request."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streetassist.request.accepted.\(requestId.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            notifiedIDs.insert(eventID)
            setNotifiedEventIDs(notifiedIDs, for: dedupeKey)
        } catch {
            print("Failed to schedule requester acceptance notification: \(error.localizedDescription)")
        }
    }

    private func notifiedEventIDs(for key: String) -> Set<String> {
        let ids = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(ids)
    }

    private func setNotifiedEventIDs(_ values: Set<String>, for key: String) {
        UserDefaults.standard.set(Array(values), forKey: key)
    }

    private func notifiedEventIDsKeyForCurrentUser() -> String {
        let auth = SupabaseManager.shared.client.auth
        let userID = auth.currentUser?.id ?? auth.currentSession?.user.id
        let scope = userID?.uuidString ?? "anonymous"
        return "\(Key.notifiedEventIDsPrefix).\(scope)"
    }

    private var notificationsAllowed: Bool {
        get async {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            return status == .authorized || status == .provisional
        }
    }
}

