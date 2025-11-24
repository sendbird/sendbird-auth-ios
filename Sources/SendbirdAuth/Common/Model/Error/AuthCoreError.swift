//
//  AuthCoreError.swift
//  SendbirdChat
//
//  Created by Kai Lee on 7/3/25.
//

import Foundation

public enum AuthCoreError: Int {
    case unknownError = 800000
    case networkError = 800120
    case networkRoutingError = 800121
    case malformedData = 800130
    case requestFailed = 800220
    case fileUploadCancelFailed = 800230
    case fileUploadCanceled = 800240
    case fileUploadTimeout = 800250
    case fileUploadTimeoutByNetwork = 800251
    case fileSizeLimitExceeded = 800260

    case internalServerError = 500901

    public var code: Int { rawValue }
    
    public var message: String {
        switch self {
        case .networkError: return "Network error has been occurred"
        case .networkRoutingError: return "Could not network request"
        case .malformedData: return "Network payload is malformed."
        case .requestFailed: return "Request couldn't be generated properly."
        case .internalServerError: return "Internal server error"
        case .fileUploadCancelFailed: return "Failed to cancel file upload."
        case .fileUploadCanceled: return "Canceled file upload."
        case .fileUploadTimeout: return "Exceeded file upload time."
        case .fileUploadTimeoutByNetwork: return "Exceeded file upload time due to bad network."
        case .fileSizeLimitExceeded: return "Exceeded file size limit."
        case .unknownError: return "Unknown error occurred."
        }
    }
    
    var asAuthError: AuthError {
        AuthError(
            domain: "core",
            code: self.code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
