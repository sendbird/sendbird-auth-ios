//
//  UserSessionExpirationHandler.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2023/07/11.
//

import Foundation

public class UserSessionExpirationHandler: SessionExpirable {
    public init(sessionToken: String, sessionHandler: SessionEventBroadcaster, config: SendbirdConfiguration) {
        self.sessionToken = sessionToken
        self.sessionHandler = sessionHandler
        self.config = config
    }
    
    public var config: SendbirdConfiguration
    
    public var sessionToken: String?
    public var sessionHandler: SessionEventBroadcaster
    
    public var isRefreshingSession: Bool = false
    
    public weak var delegate: InternalSessionDelegate?
    
    public func refreshSessionKey(shouldRetry: Bool = true, expiresIn: Int64? = nil) {
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
    
    public var timerBoard: SBTimerBoard = .init()
    public func refreshSessionToken() {
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
    
    public func resetSession() {
        self.isRefreshingSession = false
        self.sessionToken = nil
    }
}
