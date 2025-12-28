//
//  ApiClientConfig.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 12/28/25.
//

import Foundation

/// Protocol for parsing API error responses into AuthError.
/// Implement this protocol to provide custom error parsing for different API formats.
@_spi(SendbirdInternal) public protocol ApiExceptionParser {
    func parse(data: Data) -> AuthError?
}

// MARK: - Default Exception Parser

/// Default parser for Sendbird Chat API error responses.
/// Format: {"error": true, "code": 400108, "message": "..."}
///
/// This is the default parser used by Auth SDK. Other SDKs (e.g., Desk) can provide
/// their own parser implementation via `InternalInitParams.exceptionParser`.
@_spi(SendbirdInternal) public struct DefaultExceptionParser: ApiExceptionParser {
    @_spi(SendbirdInternal) public init() {}

    @_spi(SendbirdInternal) public func parse(data: Data) -> AuthError? {
        guard let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.asAuthError
    }
}
