//
//  Error.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

/// Sendbird error class.
@_spi(SendbirdInternal) public final class AuthError: NSError {
    convenience init?(dictionary: [String: Any]) {
        guard let errorMessage = dictionary["message"] as? String,
              let errorCode = dictionary["code"] as? Int,
              let chatError = AuthClientError(rawValue: errorCode) else { return nil }
        
        self.init(
            domain: (chatError as NSError).domain,
            code: chatError.rawValue,
            userInfo: [NSLocalizedDescriptionKey: errorMessage]
        )
    }

    /// Create error object with Dictionary.
    ///
    /// - Parameter dict: Error Data
    /// - Returns: `AuthError` object.
    @objc
    @_spi(SendbirdInternal) public static func error(withDictionary dict: [String: Any]) -> AuthError? {
        return AuthError(dictionary: dict)
    }
    
    /// Create error object with NSError object.
    ///
    /// - Parameter error: NSError Object.
    /// - Returns: `AuthError` object.
    @objc
    @_spi(SendbirdInternal) public static func error(withNSError error: NSError) -> AuthError {
        return AuthError(domain: error.domain, code: error.code, userInfo: error.userInfo)
    }
    
    /// Create error object
    ///
    /// - Parameter domain: domain.
    /// - Parameter code: error code.
    /// - Parameter dict: additional info in dictionary
    @_spi(SendbirdInternal) public override init(domain: String, code: Int, userInfo dict: [String: Any]? = nil) {
        super.init(domain: domain, code: code, userInfo: dict)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
        
    @_spi(SendbirdInternal) public static func error(from data: Data) -> AuthError {
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return errorResponse.asAuthError
        } else {
            return AuthError(domain: "core", code: 800000, userInfo: nil)
        }
    }
    
    var shouldRemoveCurrentUserCache: Bool {
        code == AuthClientError.accessTokenNotValid.code || shouldRevokeSession
    }
    
    var shouldRevokeSession: Bool {
        code == AuthClientError.sessionTokenRevoked.code ||
        code == AuthClientError.userDeactivated.code ||
        code == AuthClientError.userNotExist.code ||
        code == AuthClientError.notFoundInDatabase.code
    }
    
    var errorCode: AuthClientError? {
        return AuthClientError(rawValue: code)
    }

    /// Original string error code from Desk API (e.g., "desk401100")
    @_spi(SendbirdInternal) public var stringCode: String? {
        userInfo?["stringCode"] as? String
    }
}

extension Error {
    @_spi(SendbirdInternal) public func asAuthError() -> AuthError {
        return (self as? AuthError) ?? AuthError.error(withNSError: self as NSError)
    }
}
