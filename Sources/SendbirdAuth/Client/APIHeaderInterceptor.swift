//
//  APIHeaderInterceptor.swift
//  SendbirdAuth
//

import Foundation

/// Protocol for intercepting and transforming API request headers.
/// Receives the fully-constructed default headers and returns the final headers to use.
@_spi(SendbirdInternal) public protocol APIHeaderInterceptor {
    /// Intercepts the complete headers dictionary, allowing arbitrary transformation.
    /// - Parameters:
    ///   - headers: The fully-constructed default headers keyed by ``APIHeaderKey``.
    ///   - request: The API request that these headers will be sent with.
    /// - Returns: The final headers dictionary to use for the request.
    func intercept(headers: [APIHeaderKey: String], for request: any APIRequestable) -> [String: String]
}
