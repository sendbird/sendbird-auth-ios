//
//  SessionExpirable.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

import Foundation

@_spi(SendbirdInternal) public protocol SessionExpirable {
    var delegate: InternalSessionDelegate? { get set }
    var isRefreshingSession: Bool { get set }
    
    func resetSession()
    func refreshSessionKey(shouldRetry: Bool, expiresIn: Int64?)
    func refreshSessionToken()
}

extension SessionRuntime: InternalSessionDelegate {
    @_spi(SendbirdInternal) public func didSessionTokenFailToRefresh(error: AuthClientError) {
        logout()
        delegate?.sessionRefreshFailed()
        handleRefreshFailure(error: error)
    }
    
    @_spi(SendbirdInternal) public func didSessionKeyFailToRefresh(error: AuthClientError) {
        Logger.session.info("didSessionKeyFailToRefresh - error: \(error), canRefreshSession: \(canRefreshSession)")

        guard canRefreshSession == false else {
            // This SDK is the refresh owner and it failed — notify waiting SDKs
            broadcastSessionRefreshFailed()
            handleRefreshFailure(error: error)
            return
        }

        // Non-refreshable runtime delegates refresh to another runtime through the shared SessionManager.
        delegateRefreshToExternalSDK(error: error)
    }
    
    @_spi(SendbirdInternal) public func didSessionKeyRefresh(key: Session, requireReconnect: Bool) {
        // Submit the new session to the shared SessionManager (rollback prevention validation).
        if submitRefreshedSession(key) {
            // Success
        } else if session?.key == key.key {
            // Another runtime already stored the refreshed session in the shared manager.
        } else {
            return
        }

        applyRefreshedSession(key, requireReconnect: requireReconnect)
    }

    /// Applies a refreshed session that was already submitted by an external SDK,
    /// skipping `submitRefreshedSession` to avoid rejection and RequestQueue hang.
    func applyExternallyRefreshedSession(_ session: Session) {
        self.session = session
        applyRefreshedSession(session, requireReconnect: false)
    }

    private func applyRefreshedSession(_ key: Session, requireReconnect: Bool) {
        stateData?.update(with: key.key)
        sessionHandler.wasRefreshed()

        // Update connection state ONLY when session key was refreshed via API.
        // If refreshed via WS, connection state should remain Connected.
        if requireReconnect {
            delegate?.sessionReconnectRequired()
        }

        sessionHandler.didHaveError(AuthClientError.sessionKeyRefreshSucceeded.asAuthError)
        router.eventDispatcher.dispatch(command: SessionExpirationEvent.Refreshed())
    }
    
    @_spi(SendbirdInternal) public func didSessionTokenRevoke() {
        sessionHandler.wasClosed()
    }
    
    /// When refreshed via WS:
    /// stays Connected (no connection state change)
    /// When refreshed via API:
    /// Connected -> InternalDisconnected -> ReconnectingStarted -> (Refreshed) -> Reconnecting -> WebSocketConnected -> Connected
    @_spi(SendbirdInternal) public func refreshSessionKey(authToken: String?, expiringSession: Bool, expiresIn: Int64?, completionHandler: ((Bool, Session?, AuthError?) -> Void)?) {
        
        switch (router.webSocketConnectionState, expiresIn ?? 0) {
        case (.open, let time) where time >= SessionRuntime.minimumExpiresInForWSRefresh:
            requestQueue?.sendWS(
                commandType: .login,
                requestId: UUID().uuidString,
                body: .param([
                    .token: authToken,
                    .expiringSession: expiringSession
                ])
            ) { [weak self] (res: Result<LoginEvent, AuthError>) in
                guard let loginEvent = res.success,
                      let sessionKey = loginEvent.sessionKey,
                      res.failure == nil else {
                    // retry with API.
                    guard let self = self else { return }
                    
                    var headers: [String: String] = [:]
                    if let appId = self.applicationId { headers["App-Id"] = appId }
                    if let authToken { headers["Access-Token"] = authToken }

                    guard let userId = self.userId else { return }
                    self.requestQueue?.post(
                        path: URLPaths.usersSessionKey(userId: userId),
                        body: .param([.expiringSession: expiringSession]),
                        header: headers,
                        isSessionRequired: false,
                        isLoginRequired: false
                    ) { (res: Result<Session, AuthError>) in
                        completionHandler?(false, res.success, res.failure)
                    }
                    
                    return
                }
                
                let services = loginEvent.services ?? [.chat, .feed]
                let newSession = Session(key: sessionKey, services: services)
                
                completionHandler?(true, newSession, res.failure)
            }

        default:
            var headers: [String: String] = [:]
            if let appId = applicationId { headers["App-Id"] = appId }
            if let authToken { headers["Access-Token"] = authToken }

            guard let userId else { return }
            requestQueue?.post(
                path: URLPaths.usersSessionKey(userId: userId),
                body: .param([.expiringSession: expiringSession]),
                header: headers,
                isSessionRequired: false,
                isLoginRequired: false
            ) { (res: Result<Session, AuthError>) in
                completionHandler?(false, res.success, res.failure)
            }
        }
    }
}
