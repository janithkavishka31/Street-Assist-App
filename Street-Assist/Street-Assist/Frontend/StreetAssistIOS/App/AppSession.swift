import Combine
import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://mshkgrrapmoruahhlpst.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zaGtncnJhcG1vcnVhaGhscHN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU3Mzk4MTksImV4cCI6MjA5MTMxNTgxOX0.ZnGN0H4LGlVFXWjA3OsMJJl8KGEKbjH5eFM1IGuE7gk"
)

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
        guard let session = supabase.auth.currentSession, session.isExpired == false else {
            isAuthenticated = false
            return
        }

        isAuthenticated = true
    }

    private func observeAuthChanges() {
        authStateTask?.cancel()
        authStateTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for await change in supabase.auth.authStateChanges {
                self.isAuthenticated = (change.session?.isExpired == false)
            }
        }
    }
}
