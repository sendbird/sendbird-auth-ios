//
//  LoginKey.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

package enum LoginKey {
    case authToken(String)
    case none
    
    package var authToken: String? {
        if case let .authToken(authToken) = self {
            return authToken
        }
        return nil
    }
}
