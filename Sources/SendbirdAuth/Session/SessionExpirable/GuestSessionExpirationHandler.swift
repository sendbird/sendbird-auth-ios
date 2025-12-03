//
//  GuestSessionExpirationHandler.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2023/07/11.
//

import Foundation

@_spi(SendbirdInternal) public class GuestSessionExpirationHandler: SessionExpirable {
    @_spi(SendbirdInternal) public var expiringSession: Bool
    @_spi(SendbirdInternal) public var accessToken: String?

    @_spi(SendbirdInternal) public init(expiringSession: Bool, accessToken: String? = nil) {
        self.expiringSession = expiringSession
        self.accessToken = accessToken
    }
    
    @_spi(SendbirdInternal) public weak var delegate: InternalSessionDelegate?
    
    @_spi(SendbirdInternal) public var isRefreshingSession: Bool = false
    
    @_spi(SendbirdInternal) public func refreshSessionKey(shouldRetry: Bool, expiresIn: Int64?) {
        guard !isRefreshingSession else { return }
        
        isRefreshingSession = true
        
        delegate?.refreshSessionKey(authToken: accessToken, expiringSession: expiringSession, expiresIn: expiresIn, completionHandler: { refreshedViaWS, sessionKey, error in
            self.isRefreshingSession = false

            guard let sessionKey = sessionKey, error == nil else {
                Logger.session.error("Session Refresh failed with \(error?.localizedDescription ?? "")")
                self.delegate?.didSessionKeyFailToRefresh(error: AuthClientError.sessionKeyRefreshFailed)
                return
            }
            
            self.delegate?.didSessionKeyRefresh(key: sessionKey, requireReconnect: !refreshedViaWS)
        })
    }
    
    @_spi(SendbirdInternal) public func refreshSessionToken() { }
    @_spi(SendbirdInternal) public func resetSession() {
        self.isRefreshingSession = false
    }
}
