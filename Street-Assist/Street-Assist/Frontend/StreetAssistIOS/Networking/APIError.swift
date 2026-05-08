import Foundation

enum APIError: Error {
    case invalidURL
    case transportError(Error)
    case invalidResponse
    case httpError(statusCode: Int, body: Data?)
    case decodingError(Error)
}
