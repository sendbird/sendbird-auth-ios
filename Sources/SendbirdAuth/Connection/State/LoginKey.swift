//
//  LoginKey.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

public enum LoginKey {
    case authToken(String)
    case none
    
    public var authToken: String? {
        if case let .authToken(authToken) = self {
            return authToken
        }
        return nil
    }
}
