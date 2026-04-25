import Combine
import Foundation
import Supabase

@MainActor
final class AppSession: ObservableObject {
    @Published var isHelperEnabled: Bool = true
    @Published var isAuthenticated: Bool = false

    private var authStateTask: Task<Void, Never>?

    init() {
        setAuthFromCurrentSession()
        observeAuthChanges()
    }

    deinit {
        authStateTask?.cancel()
    }

    private func setAuthFromCurrentSession() {
        guard let session = SupabaseManager.shared.client.auth.currentSession, session.isExpired == false else {
            isAuthenticated = false
            return
        }

        isAuthenticated = true
    }

    private func observeAuthChanges() {
        authStateTask?.cancel()
        authStateTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for await change in SupabaseManager.shared.client.auth.authStateChanges {
                self.isAuthenticated = (change.session?.isExpired == false)
            }
        }
    }
}
