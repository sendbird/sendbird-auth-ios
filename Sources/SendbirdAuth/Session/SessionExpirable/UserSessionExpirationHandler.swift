//
//  UserSessionExpirationHandler.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2023/07/11.
//

import Foundation

package class UserSessionExpirationHandler: SessionExpirable {
    package init(sessionToken: String, sessionHandler: SessionEventBroadcaster, config: SendbirdConfiguration) {
        self.sessionToken = sessionToken
        self.sessionHandler = sessionHandler
        self.config = config
    }
    
    package var config: SendbirdConfiguration
    
    package var sessionToken: String?
    package var sessionHandler: SessionEventBroadcaster
    
    package var isRefreshingSession: Bool = false
    
    package weak var delegate: InternalSessionDelegate?
    
    package func refreshSessionKey(shouldRetry: Bool = true, expiresIn: Int64? = nil) {
        guard !isRefreshingSession else { return }
        
        isRefreshingSession = true
        
        let expiringSesion = sessionHandler.delegates.count > 0
        
        delegate?.refreshSessionKey(authToken: sessionToken, expiringSession: expiringSesion, expiresIn: expiresIn) { refreshedViaWS, sessionKey, error in
            self.isRefreshingSession = false
            
            guard let sessionKey = sessionKey, error == nil else {
                Logger.session.error("Session Refresh failed with \(error?.localizedDescription ?? "")")
                if error?.code == AuthClientError.accessTokenNotValid.rawValue && shouldRetry {
                    self.refreshSessionToken()
                } else if error?.shouldRevokeSession == true {
                    self.delegate?.didSessionTokenRevoke()
                    
                } else {
                    self.delegate?.didSessionKeyFailToRefresh(error: AuthClientError.sessionKeyRefreshFailed)
                }
                return
            }
            self.delegate?.didSessionKeyRefresh(key: sessionKey, requireReconnect: !refreshedViaWS)
        }
    }
    
    package var timerBoard: SBTimerBoard = .init()
    package func refreshSessionToken() {
        guard !isRefreshingSession else { return }

        isRefreshingSession = true
        
        _ = SBTimer(
            timeInterval: config.sessionTokenRefreshTimeoutSec,
            userInfo: nil,
            onBoard: self.timerBoard,
            expirationHandler: { [weak self] in
                guard let self = self else { return }
                self.isRefreshingSession = false
                
                self.delegate?.didSessionTokenFailToRefresh(error: AuthClientError.sessionKeyRefreshFailed)
            }
        )
        
        sessionHandler.didTokenRequire { [self] token in
            self.isRefreshingSession = false
            self.timerBoard.stopAll()
            
            guard let token = token else { return }
            
            self.sessionToken = token
            self.refreshSessionKey(shouldRetry: false, expiresIn: nil)
        } failCompletion: { [self] in
            self.isRefreshingSession = false
            self.timerBoard.stopAll()
            
            self.delegate?.didSessionTokenFailToRefresh(error: AuthClientError.passedInvalidAccessToken)
        }
    }
    
    package func resetSession() {
        self.isRefreshingSession = false
        self.sessionToken = nil
    }
}
