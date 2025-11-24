//
//  ErrorResponse.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/4/25.
//

import Foundation

public struct ErrorResponse: Decodable {
    public let message: String
    public let code: Int
    
    public init(message: String, code: Int) {
        self.message = message
        self.code = code
    }
    
    public var asAuthError: AuthError {
        AuthError(
            domain: "network",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
