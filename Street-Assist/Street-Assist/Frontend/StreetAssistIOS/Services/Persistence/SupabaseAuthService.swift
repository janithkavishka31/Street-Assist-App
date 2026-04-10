import Foundation
import Supabase

enum SupabaseAuthServiceError: LocalizedError {
    case invalidEmail
    case emptyPassword

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .emptyPassword:
            return "Please enter your password."
        }
    }
}

final class SupabaseAuthService {
    @discardableResult
    func signInEmail(
        email: String,
        password: String
    ) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@") else {
            throw SupabaseAuthServiceError.invalidEmail
        }

        guard !password.isEmpty else {
            throw SupabaseAuthServiceError.emptyPassword
        }

        _ = try await supabase.auth.signIn(email: trimmedEmail, password: password)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    func signUpEmail(
        fullName: String,
        email: String,
        phone: String,
        password: String,
        agreedToTerms: Bool,
        quickBio: String?,
        skills: [String]?
    ) async throws -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedEmail.contains("@") else {
            throw SupabaseAuthServiceError.invalidEmail
        }

        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBio = (quickBio ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        var data: [String: AnyJSON] = [
            "full_name": .string(fullName.trimmingCharacters(in: .whitespacesAndNewlines)),
            "agreed_to_terms": .bool(agreedToTerms)
        ]

        if !trimmedPhone.isEmpty {
            data["phone"] = .string(trimmedPhone)
        }

        if !trimmedBio.isEmpty {
            data["quick_bio"] = .string(trimmedBio)
        }

        if let skills, !skills.isEmpty {
            data["skills"] = .array(skills.map { .string($0) })
        }

        let response = try await supabase.auth.signUp(
            email: trimmedEmail,
            password: password,
            data: data
        )

        return response.session != nil
    }
}
