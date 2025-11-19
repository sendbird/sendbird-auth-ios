//
//  AuthClientError.swift
//  SendbirdChat
//
//  Created by wooyoung chung on 2/11/22.
//

import Foundation

// MARK: - SendbirdAuth Specific Error Cases
package enum AuthClientError: Int, Error {
    // Connection related errors
    case connectionRequired = 800101
    case connectionCanceled = 800102
    case webSocketConnectionClosed = 800200
    case webSocketConnectionFailed = 800210
    case serverOverloaded = 800221  // [NEXT_VERSION]
    
    // Timer related errors
    case timerWasExpired = 800301
    case timerWasAlreadyDone = 800302
    case ackTimeout = 800180
    case loginTimeout = 800190
    case reconnectLoginTimeout = 800191
    
    // Authentication related errors
    case accessTokenNotValid = 400302
    case sessionKeyExpired = 400309
    case sessionTokenRevoked = 400310
    case sessionKeyRefreshSucceeded = 800501
    case sessionKeyRefreshFailed = 800502
    case passedInvalidAccessToken = 800500
    
    // Parameter related errors
    case invalidParameter = 800110
    case invalidInitialization = 800100
    
    // General errors
    case unknownError = 800000
    case notResolved = 800800
    
    // Network related errors
    case networkError = 800120
    case requestFailed = 800220
    case malformedData = 800130
    case internalServerError = 500901
    
    // File upload related errors
    case fileUploadCanceled = 800240
    case fileUploadCancelFailed = 800230
    
    // User related errors
    case notFoundInDatabase = 400201
    case userDeactivated = 400300
    case userNotExist = 400301
    
    // State related errors
    case statUploadNotAllowed = 403200
}

// MARK: - AuthClientError Extensions
extension AuthClientError: Decodable {
    package init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = AuthClientError(rawValue: try container.decode(Int.self)) ?? .unknownError
    }
}

extension AuthClientError: CustomStringConvertible {
    package var description: String {
        message
    }
    
    package var message: String {
        switch self {
        case .unknownError: return "Unknown error occurred."
        case .invalidInitialization: return "Initialization has not been done yet."
        case .connectionRequired: return "Connection required."
        case .connectionCanceled: return "Connection has been canceled."
        case .invalidParameter: return "Invalid parameter has been used."
        case .ackTimeout: return "Exceeded acknowledgement timeout."
        case .loginTimeout: return "Exceeded login timeout."
        case .reconnectLoginTimeout: return "Exceeded reconnect login timeout."
        case .webSocketConnectionClosed: return "Websocket connection has been closed."
        case .webSocketConnectionFailed: return "Websocket connection has been failed."
        case .timerWasExpired: return "Exceeded internal command timeout"
        case .timerWasAlreadyDone: return "The timer was already done. Duplicated execute."
        case .passedInvalidAccessToken: return "Given access token is not valid."
        case .sessionKeyRefreshSucceeded: return "Session was expired and refreshed."
        case .sessionKeyRefreshFailed: return "Session was expired and failed to refresh."
            // core
        case .networkError: return "Network error has been occurred"
        case .malformedData: return "Network payload is malformed."
        case .requestFailed: return "Request couldn't be generated properly."
        case .internalServerError: return "Internal server error"
        case .fileUploadCancelFailed: return "Failed to cancel file upload."
        case .fileUploadCanceled: return "Canceled file upload."
        case .notResolved: return "The object is not resolved. Please call resolved(with:) before calling this method."
        default: return (self as NSError).domain
        }
    }
}
    
extension AuthClientError {
    var code: Int { rawValue }
    
    var asAuthError: AuthError {
        asAuthError()
    }
    
    func asAuthError(message: ErrorMessage) -> AuthError {
        asAuthError(message: message.description, extraUserInfo: nil)
    }

    func asAuthError(message: String? = nil, failureReason: String? = nil) -> AuthError {
        var userInfo: [String: Any] = [:]
        userInfo[NSLocalizedDescriptionKey] = message ?? self.message
        if let reason = failureReason {
            userInfo[NSLocalizedFailureReasonErrorKey] = reason
        }
        return asAuthError(message: message, extraUserInfo: userInfo)
    }

    func asAuthError(message: String?, extraUserInfo: [String: Any]?) -> AuthError {
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: message ?? self.message
        ]
        extraUserInfo?.forEach { key, value in
            userInfo[key] = value
        }
        
        return AuthError(domain: "core", code: rawValue, userInfo: userInfo)
    }
}
