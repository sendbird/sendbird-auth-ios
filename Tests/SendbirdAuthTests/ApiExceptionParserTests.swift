//
//  ApiExceptionParserTests.swift
//  SendbirdAuthTests
//
//  Created by Kai Lee on 12/31/25.
//

import XCTest
@_spi(SendbirdInternal) @testable import SendbirdAuthSDK

final class ApiExceptionParserTests: XCTestCase {
    // MARK: - DefaultExceptionParser Tests

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
        XCTAssertEqual(error?.code, 400108)
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
