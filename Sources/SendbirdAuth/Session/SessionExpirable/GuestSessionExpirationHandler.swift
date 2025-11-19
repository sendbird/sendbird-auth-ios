//
//  GuestSessionExpirationHandler.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2023/07/11.
//

import Foundation

package class GuestSessionExpirationHandler: SessionExpirable {
    package var expiringSession: Bool
    package var accessToken: String?

    package init(expiringSession: Bool, accessToken: String? = nil) {
        self.expiringSession = expiringSession
        self.accessToken = accessToken
    }
    
    package weak var delegate: InternalSessionDelegate?
    
    package var isRefreshingSession: Bool = false
    
    package func refreshSessionKey(shouldRetry: Bool, expiresIn: Int64?) {
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
    
    package func refreshSessionToken() { }
    package func resetSession() {
        self.isRefreshingSession = false
    }
}
