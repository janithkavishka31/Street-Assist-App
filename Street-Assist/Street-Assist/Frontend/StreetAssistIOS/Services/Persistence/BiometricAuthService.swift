import Foundation
import LocalAuthentication
import Security

enum BiometricAuthServiceError: LocalizedError {
    case unavailable
    case noStoredCredentials
    case failedAuthentication
    case encodingFailure
    case unknown

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Face ID is not available on this device."
        case .noStoredCredentials:
            return "No saved login found. Please login once with email and password."
        case .failedAuthentication:
            return "Face ID authentication failed."
        case .encodingFailure:
            return "Unable to securely save login details."
        case .unknown:
            return "Unable to complete Face ID login."
        }
    }
}

final class BiometricAuthService {
    static let shared = BiometricAuthService()

    private let service = "cw.Street-Assist.auth"
    private let account = "primary_user"

    private init() {}

    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func hasStoredCredentials() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: false
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func saveCredentials(email: String, password: String) throws {
        let payload = "\(email)\n\(password)"
        guard let data = payload.data(using: .utf8) else {
            throw BiometricAuthServiceError.encodingFailure
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricAuthServiceError.unknown
        }
    }

    func clearStoredCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    func loadCredentialsWithBiometrics(reason: String) async throws -> (email: String, password: String) {
        guard canUseBiometrics() else {
            throw BiometricAuthServiceError.unavailable
        }

        let context = LAContext()
        let authenticated = try await evaluateBiometrics(context: context, reason: reason)
        guard authenticated else {
            throw BiometricAuthServiceError.failedAuthentication
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let payload = String(data: data, encoding: .utf8)
        else {
            throw BiometricAuthServiceError.noStoredCredentials
        }

        let parts = payload.components(separatedBy: "\n")
        guard parts.count >= 2 else {
            throw BiometricAuthServiceError.noStoredCredentials
        }

        return (parts[0], parts.dropFirst().joined(separator: "\n"))
    }

    private func evaluateBiometrics(context: LAContext, reason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: success)
            }
        }
    }
}
