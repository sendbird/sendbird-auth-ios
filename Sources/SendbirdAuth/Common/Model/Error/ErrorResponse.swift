//
//  ErrorResponse.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/4/25.
//

import Foundation

package struct ErrorResponse: Decodable {
    package let message: String
    package let code: Int
    
    package init(message: String, code: Int) {
        self.message = message
        self.code = code
    }
    
    package var asAuthError: AuthError {
        AuthError(
            domain: "network",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
