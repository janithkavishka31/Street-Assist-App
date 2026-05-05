import Foundation
import Supabase
import UIKit

class StorageService {
    static let shared = StorageService()
    private let bucketName = "request-photos"
    private let zoneDocumentBucketName = "zone-documents"

    private init() {}

    func uploadImage(_ image: UIImage, fileName: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "StorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }

        let filePath = "\(UUID().uuidString)-\(fileName).jpg"

        _ = try await SupabaseManager.shared.client.storage
            .from(bucketName)
            .upload(path: filePath, file: imageData, options: FileOptions(contentType: "image/jpeg"))

        let publicURL = try SupabaseManager.shared.client.storage
            .from(bucketName)
            .getPublicURL(path: filePath)

        return publicURL.absoluteString
    }

    func uploadZoneDocument(_ image: UIImage, fileName: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "StorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }

        return try await uploadZoneDocument(
            data: imageData,
            fileName: fileName,
            contentType: "image/jpeg",
            fileExtension: "jpg"
        )
    }

    func uploadZoneDocument(
        data: Data,
        fileName: String,
        contentType: String,
        fileExtension: String
    ) async throws -> String {
        let sanitizedExtension = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "bin" : fileExtension
        let filePath = "\(UUID().uuidString)-\(fileName).\(sanitizedExtension)"

        _ = try await SupabaseManager.shared.client.storage
            .from(zoneDocumentBucketName)
            .upload(path: filePath, file: data, options: FileOptions(contentType: contentType))

        let publicURL = try SupabaseManager.shared.client.storage
            .from(zoneDocumentBucketName)
            .getPublicURL(path: filePath)

        return publicURL.absoluteString
    }
}