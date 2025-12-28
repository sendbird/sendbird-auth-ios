//
//  ApiClientConfig.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 12/28/25.
//

import Foundation

/// Protocol for parsing API error responses into AuthError
@_spi(SendbirdInternal) public protocol ApiExceptionParser {
    func parse(data: Data) -> AuthError?
}

/// Configuration for different API clients (Chat, Desk, etc.)
@_spi(SendbirdInternal) public enum ApiClientConfig {
    case chat
    case desk

    @_spi(SendbirdInternal) public var exceptionParser: ApiExceptionParser {
        switch self {
        case .chat:
            return ChatExceptionParser()
        case .desk:
            return DeskExceptionParser()
        }
    }
}

// MARK: - Chat Exception Parser

/// Parser for Chat API error responses
/// Format: {"error": true, "code": 400108, "message": "..."}
struct ChatExceptionParser: ApiExceptionParser {
    func parse(data: Data) -> AuthError? {
        guard let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) else {
            return nil
        }
        return errorResponse.asAuthError
    }
}

// MARK: - Desk Exception Parser

private let ERR_CODE_DESK_AUTH = "desk401100"

/// Parser for Desk API error responses
/// Format: {"code": "desk401100", "detail": "..."}
struct DeskExceptionParser: ApiExceptionParser {
    func parse(data: Data) -> AuthError? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deskCode = json["code"] as? String else {
            return nil
        }

        let detail = (json["detail"] as? String) ?? ""
        let errorCode: Int

        if deskCode == ERR_CODE_DESK_AUTH {
            errorCode = AuthClientError.nonAuthorized.rawValue
        } else {
            errorCode = AuthClientError.requestFailed.rawValue
        }

        return AuthError(
            domain: "desk",
            code: errorCode,
            userInfo: [
                NSLocalizedDescriptionKey: "[\(deskCode)] \(detail)",
                "stringCode": deskCode
            ]
        )
    }
}
