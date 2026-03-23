//
//  APIHeaderKey.swift
//  SendbirdAuth
//

import Foundation

/// Enum defining all HTTP header keys used by CommandRouter.
/// Use with `APIHeaderInterceptor` to override header names for custom API requirements.
@_spi(SendbirdInternal) public enum APIHeaderKey: String, CaseIterable {
    // Standard HTTP
    case accept = "Accept"
    case connection = "Connection"

    // Sendbird-specific
    case requestSentTimestamp = "Request-Sent-Timestamp"
    case sendbird = "SendBird"
    case userAgent = "User-Agent"
    case sbUserAgent = "SB-User-Agent"
    case sbSdkUserAgent = "SB-SDK-User-Agent"

    // Authentication
    case sessionKey = "Session-Key"
}
