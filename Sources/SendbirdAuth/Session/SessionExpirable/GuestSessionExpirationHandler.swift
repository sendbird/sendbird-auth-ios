//
//  GuestSessionExpirationHandler.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2023/07/11.
//

import Foundation

public class GuestSessionExpirationHandler: SessionExpirable {
    public var expiringSession: Bool
    public var accessToken: String?

    public init(expiringSession: Bool, accessToken: String? = nil) {
        self.expiringSession = expiringSession
        self.accessToken = accessToken
    }
    
    public weak var delegate: InternalSessionDelegate?
    
    public var isRefreshingSession: Bool = false
    
    public func refreshSessionKey(shouldRetry: Bool, expiresIn: Int64?) {
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
    
    public func refreshSessionToken() { }
    public func resetSession() {
        self.isRefreshingSession = false
    }
}
