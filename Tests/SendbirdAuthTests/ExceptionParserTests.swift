//
//  ExceptionParserTests.swift
//  SendbirdAuthTests
//
//  Created by Kai Lee on 12/31/25.
//

import XCTest
@_spi(SendbirdInternal) @testable import SendbirdAuthSDK

final class DefaultExceptionParserTests: XCTestCase {
    // MARK: - DefaultExceptionParser Tests

    func testInternalInitParams_exceptionParser_isPassedToRouterConfig() {
        // Given
        let customParser = DefaultExceptionParser()
        let params = InternalInitParams(
            applicationId: "test-app-id",
            isLocalCachingEnabled: false,
            exceptionParser: customParser
        )

        // When
        let authMain = SendbirdAuthMain(params: params)

        // Then
        XCTAssertTrue(authMain.router.apiClient.routerConfig.exceptionParser is DefaultExceptionParser)
    }

    func testDefaultExceptionParser_validErrorResponse_returnsAuthError() {
        // Given
        let parser = DefaultExceptionParser()
        let errorJSON = """
        {
            "error": true,
            "code": 400108,
            "message": "User not found"
        }
        """.data(using: .utf8)!

        // When
        let error = parser.parse(data: errorJSON)

        // Then
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.code, 400_108)
        XCTAssertEqual(error?.localizedDescription, "User not found")
    }

    func testDefaultExceptionParser_invalidJSON_returnsNil() {
        // Given
        let parser = DefaultExceptionParser()
        let invalidJSON = "not a json".data(using: .utf8)!

        // When
        let error = parser.parse(data: invalidJSON)

        // Then
        XCTAssertNil(error)
    }

    func testDefaultExceptionParser_missingCode_returnsNil() {
        // Given
        let parser = DefaultExceptionParser()
        let errorJSON = """
        {
            "error": true,
            "message": "Some error"
        }
        """.data(using: .utf8)!

        // When
        let error = parser.parse(data: errorJSON)

        // Then
        XCTAssertNil(error)
    }

    func testDefaultExceptionParser_missingMessage_returnsNil() {
        // Given
        let parser = DefaultExceptionParser()
        let errorJSON = """
        {
            "error": true,
            "code": 400108
        }
        """.data(using: .utf8)!

        // When
        let error = parser.parse(data: errorJSON)

        // Then
        XCTAssertNil(error)
    }
}

// MARK: - HTTPClient Exception Parser Integration Tests

final class HTTPClientExceptionParserTests: XCTestCase {
    private var httpClient: HTTPClient!
    private var mockParser: MockExceptionParser!

    override func setUp() {
        super.setUp()
        mockParser = MockExceptionParser()

        let config = CommandRouterConfiguration(
            cachePolicy: .reloadIgnoringCacheData,
            apiHost: "https://api.test.com",
            wsHost: "wss://ws.test.com",
            exceptionParser: mockParser
        )
        httpClient = HTTPClient(routerConfig: config)
        httpClient.markDependencyResolvedForTest()

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: sessionConfig)
        httpClient.setURLSessionForTest(mockSession)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        httpClient = nil
        mockParser = nil
        super.tearDown()
    }

    func testHTTPClient_on400Error_callsInjectedExceptionParser() {
        // Given
        let expectation = expectation(description: "Request completed")
        let errorData = """
        {
            "error": true,
            "code": 400999,
            "message": "Custom error from parser"
        }
        """.data(using: .utf8)!

        mockParser.mockResult = AuthError(
            domain: "test",
            code: 400_999,
            userInfo: [NSLocalizedDescriptionKey: "Custom error from parser"]
        )

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, errorData)
        }

        // When
        let request = TestAPIRequest()
        httpClient.send(request: request) { result, error in
            // Then
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.code, 400_999)
            XCTAssertEqual(self.mockParser.parseCallCount, 1)
            XCTAssertEqual(self.mockParser.lastParsedData, errorData)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testHTTPClient_on400Error_parserReturnsNil_fallsBackToDefault() {
        // Given
        let expectation = expectation(description: "Request completed")
        let errorData = """
        {
            "error": true,
            "code": 400108,
            "message": "Fallback error"
        }
        """.data(using: .utf8)!

        mockParser.mockResult = nil // Parser returns nil, should fallback

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, errorData)
        }

        // When
        let request = TestAPIRequest()
        httpClient.send(request: request) { result, error in
            // Then
            XCTAssertNil(result)
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.code, 400_108) // Fallback AuthError.error(from:)
            XCTAssertEqual(self.mockParser.parseCallCount, 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }

    func testHTTPClient_on200Success_doesNotCallParser() {
        // Given
        let expectation = expectation(description: "Request completed")
        let successData = "{}".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, successData)
        }

        // When
        let request = TestAPIRequest()
        httpClient.send(request: request) { _, _ in
            // Then
            XCTAssertEqual(self.mockParser.parseCallCount, 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
    }
}

    // MARK: - SendbirdAuthMain E2E Tests

    func testSendbirdAuthMain_authenticate_on400Error_usesCustomExceptionParser() {
        // Given
        let expectation = expectation(description: "Authenticate completed")
        let customMockParser = MockExceptionParser()

        let params = InternalInitParams(
            applicationId: "test-app-id",
            isLocalCachingEnabled: false,
            exceptionParser: customMockParser
        )
        let authMain = SendbirdAuthMain(params: params)

        // Inject mock URLSession to HTTPClient
        if let client = authMain.router.apiClient as? HTTPClient {
            client.markDependencyResolvedForTest()

            let sessionConfig = URLSessionConfiguration.ephemeral
            sessionConfig.protocolClasses = [MockURLProtocol.self]
            let mockSession = URLSession(configuration: sessionConfig)
            client.setURLSessionForTest(mockSession)
        }

        // Custom error format (e.g., Desk API format)
        let errorData = """
        {
            "error": true,
            "code": 500100,
            "message": "Desk specific error"
        }
        """.data(using: .utf8)!

        customMockParser.mockResult = AuthError(
            domain: "DeskError",
            code: 500100,
            userInfo: [NSLocalizedDescriptionKey: "Desk specific error"]
        )

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, errorData)
        }

        // When
        authMain.authenticate(
            userId: "test-user",
            completionHandler: { user, error in
                // Then
                XCTAssertNil(user)
                XCTAssertNotNil(error)
                XCTAssertEqual(error?.code, 500100)
                XCTAssertEqual(error?.localizedDescription, "Desk specific error")
                XCTAssertGreaterThan(customMockParser.parseCallCount, 0, "Custom parser should be called")
                expectation.fulfill()
            }
        )

        wait(for: [expectation], timeout: 5.0)
    }

// MARK: - Test Helpers

private class MockExceptionParser: ApiExceptionParser {
    var parseCallCount = 0
    var lastParsedData: Data?
    var mockResult: AuthError?

    func parse(data: Data) -> AuthError? {
        parseCallCount += 1
        lastParsedData = data
        return mockResult
    }
}

private class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with _: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("requestHandler not set")
        }

        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private struct TestAPIRequest: APIRequestable {
    var resultType: EmptyResponse.Type { EmptyResponse.self }

    var method: HTTPMethod { .get }
    var url: URLPath { URLPath(array: ["test"]) }
    var isSessionRequired: Bool { false }
    var isLoginRequired: Bool { false }

    func encode(to _: Encoder) throws {}
}

private struct EmptyResponse: Decodable {}
