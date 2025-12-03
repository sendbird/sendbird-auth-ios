//
//  ErrorResponse.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/4/25.
//

import Foundation

@_spi(SendbirdInternal) public struct ErrorResponse: Decodable {
    @_spi(SendbirdInternal) public let message: String
    @_spi(SendbirdInternal) public let code: Int
    
    @_spi(SendbirdInternal) public init(message: String, code: Int) {
        self.message = message
        self.code = code
    }
    
    @_spi(SendbirdInternal) public var asAuthError: AuthError {
        AuthError(
            domain: "network",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
