import Foundation
import XCTest
@testable import Street_Assist

final class StreetAssistCoreTests: XCTestCase {
    func test_generateJoinCode_usesProvidedPrefix() {
        let code = HelpZoneService.shared.generateJoinCode(prefix: "UNI")
        XCTAssertTrue(code.hasPrefix("UNI-"))
    }

    func test_generateJoinCode_hasExpectedLengthAndCharacters() {
        let code = HelpZoneService.shared.generateJoinCode(prefix: "ZONE")
        let parts = code.split(separator: "-")

        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts[1].count, 5)
        XCTAssertTrue(parts[1].allSatisfy { $0.isNumber || $0.isUppercase })
    }

    func test_signInEmail_throwsForInvalidEmail() async {
        let service = SupabaseAuthService()

        do {
            try await service.signInEmail(email: "invalid-email", password: "abc123")
            XCTFail("Expected invalid email error")
        } catch let error as SupabaseAuthServiceError {
            if case .invalidEmail = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Wrong auth error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_signInEmail_throwsForEmptyPassword() async {
        let service = SupabaseAuthService()

        do {
            try await service.signInEmail(email: "student@example.com", password: "")
            XCTFail("Expected empty password error")
        } catch let error as SupabaseAuthServiceError {
            if case .emptyPassword = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Wrong auth error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_apiClient_returnsDecodedResponse() async throws {
        let expected = SimpleResponse(message: "ok")
        URLProtocolMock.mockResult = .success(
            statusCode: 200,
            data: try JSONEncoder().encode(expected)
        )

        let client = makeClient()
        let result: SimpleResponse = try await client.request(path: "/hello", responseType: SimpleResponse.self)

        XCTAssertEqual(result.message, "ok")
    }

    func test_apiClient_throwsInvalidResponseWhenNotHTTPResponse() async {
        URLProtocolMock.mockResult = .nonHTTPResponse
        let client = makeClient()

        do {
            let _: SimpleResponse = try await client.request(path: "/hello", responseType: SimpleResponse.self)
            XCTFail("Expected invalid response error")
        } catch let error as APIError {
            if case .invalidResponse = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Unexpected APIError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_apiClient_throwsHttpErrorFor400() async {
        URLProtocolMock.mockResult = .success(statusCode: 400, data: Data("bad".utf8))
        let client = makeClient()

        do {
            let _: SimpleResponse = try await client.request(path: "/hello", responseType: SimpleResponse.self)
            XCTFail("Expected HTTP error")
        } catch let error as APIError {
            if case let .httpError(statusCode, body) = error {
                XCTAssertEqual(statusCode, 400)
                XCTAssertEqual(body, Data("bad".utf8))
            } else {
                XCTFail("Unexpected APIError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_apiClient_throwsDecodingErrorForWrongPayload() async {
        URLProtocolMock.mockResult = .success(statusCode: 200, data: Data("{\"wrong\":1}".utf8))
        let client = makeClient()

        do {
            let _: SimpleResponse = try await client.request(path: "/hello", responseType: SimpleResponse.self)
            XCTFail("Expected decoding error")
        } catch let error as APIError {
            if case .decodingError = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Unexpected APIError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_apiClient_wrapsTransportError() async {
        URLProtocolMock.mockResult = .failure(URLError(.notConnectedToInternet))
        let client = makeClient()

        do {
            let _: SimpleResponse = try await client.request(path: "/hello", responseType: SimpleResponse.self)
            XCTFail("Expected transport error")
        } catch let error as APIError {
            if case .transportError = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Unexpected APIError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_helpRequest_decodesSnakeCasePayload() throws {
        let requestId = UUID()
        let userId = UUID()
        let json = """
        {
          "id": "\(requestId.uuidString)",
          "requester_user_id": "\(userId.uuidString)",
          "category": "technicalAndRepair",
          "service_title": "Technical & Repair",
          "description": "Laptop fan issue",
          "latitude": 6.9271,
          "longitude": 79.8612,
          "scope": "help_zone_only",
          "zone_id": null,
          "status": "open",
          "requester_completed_at": null,
          "created_at": "2026-05-08T12:00:00Z",
          "updated_at": "2026-05-08T12:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let model = try decoder.decode(HelpRequest.self, from: Data(json.utf8))

        XCTAssertEqual(model.id, requestId)
        XCTAssertEqual(model.requesterUserId, userId)
        XCTAssertEqual(model.category, .technicalAndRepair)
        XCTAssertEqual(model.scope, .helpZoneOnly)
        XCTAssertEqual(model.status, .open)
    }

    func test_userSettings_decodesRawValues() throws {
        let userId = UUID()
        let json = """
        {
          "user_id": "\(userId.uuidString)",
          "is_helper_enabled": true,
          "default_scope": "help_zone_and_global",
          "updated_at": "2026-05-08T10:30:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let settings = try decoder.decode(UserSettings.self, from: Data(json.utf8))

        XCTAssertEqual(settings.userId, userId)
        XCTAssertTrue(settings.isHelperEnabled)
        XCTAssertEqual(settings.defaultScope, .helpZoneAndGlobal)
    }

    func test_authErrorMessages_areReadable() {
        XCTAssertEqual(SupabaseAuthServiceError.invalidEmail.errorDescription, "Please enter a valid email address.")
        XCTAssertEqual(SupabaseAuthServiceError.emptyPassword.errorDescription, "Please enter your password.")
    }

    private func makeClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: config)
        return APIClient(baseURL: URL(string: "https://example.com")!, urlSession: session)
    }
}

private struct SimpleResponse: Codable {
    let message: String
}

private final class URLProtocolMock: URLProtocol {
    enum MockResult {
        case success(statusCode: Int, data: Data)
        case failure(Error)
        case nonHTTPResponse
    }

    static var mockResult: MockResult = .success(statusCode: 200, data: Data())

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        switch Self.mockResult {
        case let .success(statusCode, data):
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        case .nonHTTPResponse:
            let response = URLResponse(
                url: request.url ?? URL(string: "https://example.com")!,
                mimeType: "application/json",
                expectedContentLength: 0,
                textEncodingName: nil
            )
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
