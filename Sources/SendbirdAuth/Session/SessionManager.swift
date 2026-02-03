//
//  SessionManager.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

@_spi(SendbirdInternal) public class SessionManager: Injectable {
    @_spi(SendbirdInternal) public enum SessionState {
        case connected
        case refreshing
        case none
    }
    
    @_spi(SendbirdInternal) public var state: SessionState {
        if expirationHandler.isRefreshingSession {
            return .refreshing
        } else if session != nil {
            return .connected
        } else {
            return .none
        }
    }
    
    @_spi(SendbirdInternal) public static let minimumExpiresInForWSRefresh = 5
    
    @InternalAtomic @_spi(SendbirdInternal) public var internalSession: Session?
    
    @_spi(SendbirdInternal) public var session: Session? {
        get {
            // Provider가 있으면 provider에서 조회
            if let provider = sessionProvider {
                return provider.session(for: userId)
            }
            // 기존 로직 (provider 없는 경우 fallback)
            let defaultKey = Session.buildFromUserDefaults()
            if internalSession == nil {
                internalSession = defaultKey
            } else if let sessionKey = internalSession,
                      sessionKey != defaultKey {
                if let userId = stateData?.currentUser?.userId {
                    Session.saveToUserDefaults(session: sessionKey, userId: userId)
                } else {
                    Session.clearUserDefaults()
                }
            }
            return internalSession
        }

        set {
            if let provider = sessionProvider {
                // Provider가 있으면 provider에 저장 (영속성도 provider가 담당)
                provider.setSession(newValue, for: userId)
            } else {
                // 기존 로직
                internalSession = newValue
                if let sessionKey = newValue, let userId = stateData?.currentUser?.userId {
                    Session.saveToUserDefaults(session: sessionKey, userId: userId)
                } else {
                    Session.clearUserDefaults()
                }
            }
            delegate?.sessionKeyChanged(newValue?.key)
        }
    }
    
    @_spi(SendbirdInternal) public let applicationId: String
    @InternalAtomic @_spi(SendbirdInternal) public var eKey: String?

    @_spi(SendbirdInternal) public private(set) var userId: String

    @_spi(SendbirdInternal) public private(set) var sessionProvider: SessionProvider?

    private let board: SBTimerBoard
    
    @_spi(SendbirdInternal) public var sessionHandler: SessionEventBroadcaster
    
    @_spi(SendbirdInternal) public weak var delegate: SessionManagerDelegate?
    
    @_spi(SendbirdInternal) public var localCachePreference: LocalPreferences

    @DependencyWrapper private var dependency: Dependency?
    private var service: QueueService? { dependency?.service }
    @_spi(SendbirdInternal) public var stateData: ConnectionStateData? { dependency?.stateData }
    var requestQueue: RequestQueue? { dependency?.requestQueue }
    private var config: SendbirdConfiguration? { dependency?.config }
    private var isLocalCachingEnabled: Bool
    
    @_spi(SendbirdInternal) public var router: CommandRouter
    @_spi(SendbirdInternal) public var expirationHandler: SessionExpirable
    @_spi(SendbirdInternal) public var isRefreshingSession: Bool { expirationHandler.isRefreshingSession }
    
    @InternalAtomic @_spi(SendbirdInternal) public var authenticateHandlers: [AuthUserHandler?] = []
    @_spi(SendbirdInternal) public var authenticateQueue: DispatchQueue
    @_spi(SendbirdInternal) public var isAuthenticating = false
    
    @_spi(SendbirdInternal) public init(
        applicationId: String,
        userId: String,
        router: CommandRouter,
        sessionHandler: SessionEventBroadcaster,
        isLocalCachingEnabled: Bool,
        localCachePreference: LocalPreferences,
        config: SendbirdConfiguration,
        sessionProvider: SessionProvider? = nil
    ) {
        self.sessionHandler = sessionHandler

        self.router = router
        self.board = SBTimerBoard(capacity: 1)

        self.applicationId = applicationId
        self.userId = userId
        self.expirationHandler = GuestSessionExpirationHandler(expiringSession: false)

        self.localCachePreference = localCachePreference
        self.isLocalCachingEnabled = isLocalCachingEnabled
        self.authenticateQueue = DispatchQueue(label: "com.sendbird.chat.session.authenticate.\(userId)")

        self.sessionProvider = sessionProvider
        sessionProvider?.onSessionChanged { [weak self] session, userId in
            guard let self, userId == self.userId else { return }
            self.delegate?.sessionKeyChanged(session?.key)
        }
    }

    @_spi(SendbirdInternal) public weak var requestHeaderDataSource: RequestHeaderDataSource?
    
    @_spi(SendbirdInternal) public func authenticate(authData: AuthData?, loginHandler: AuthUserHandler?) {
        guard let config = self.config,
                let stateData = self.stateData else {
            let error = AuthClientError.notResolved.asAuthError
            loginHandler?(nil, error)
            return
        }

        if router.connected {
            loginHandler?(stateData.currentUser, nil)
            return
        }
        
        authenticateQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.authenticateHandlers.append(loginHandler)
            
            guard !self.isAuthenticating else {
                return
            }
            
            self.isAuthenticating = true
            
            let useExpiringSession: Bool
            if let authData = authData {
                switch authData.authTokenType {
                case .accessToken:
                    if self.requestHeaderDataSource?.sessionDelegate != nil {
                        // if customer has registered session delegate, use it
                        self.expirationHandler = UserSessionExpirationHandler(
                            sessionToken: authData.authToken,
                            sessionHandler: self.sessionHandler,
                            config: config
                        )
                    } else {
                        // if not, register dummy session delegate
                        self.expirationHandler = GuestSessionExpirationHandler(
                            expiringSession: true,
                            accessToken: authData.authToken
                        )
                    }
                    useExpiringSession = true
                case .sessionToken:
                    self.expirationHandler = UserSessionExpirationHandler(
                        sessionToken: authData.authToken,
                        sessionHandler: self.sessionHandler,
                        config: config
                    )
                    // SessionHandler should be set when using authToken
                    useExpiringSession = self.requestHeaderDataSource?.isExpiringSession ?? false
                }
            } else {
                self.expirationHandler = GuestSessionExpirationHandler(expiringSession: true)
                useExpiringSession = true // Always requst expiring session for guest
            }
            self.expirationHandler.delegate = self
            
            let authenticateRequest = AuthenticateRequest(
                userId: self.userId,
                applicationId: stateData.applicationId,
                authToken: authData?.authToken,
                expiringSession: useExpiringSession,
                requestHeaderDataSource: requestHeaderDataSource,
                includeLOGI: true,
                useLocalCache: self.isLocalCachingEnabled
            )
            
            self.router.send(request: authenticateRequest, sessionKey: nil) { [weak self] response, error  in
                guard let self = self else { return }
                
                self.authenticateQueue.async {
                    defer { self.isAuthenticating = false }
                    
                    let copiedHandlers = self.authenticateHandlers
                    self.authenticateHandlers.removeAll()
                    
                    guard let response = response, error == nil else {
                        let currentUser = error?.shouldRemoveCurrentUserCache == true ? nil : stateData.currentUser
                        self.service? {
                            copiedHandlers.forEach { $0?(currentUser, error) }
                        }
                        return
                    }
                    
                    let connectedEvent = ConnectionStateEvent.Connected(loginEvent: response, isReconnected: false)
                    self.router.eventDispatcher.dispatch(command: connectedEvent)
                    self.router.eventDispatcher.dispatch(command: connectedEvent.loginEvent) {
                        self.service? {
                            copiedHandlers.forEach { $0?(response.user, error) }
                        }
                    }
                }
            }
        }
    }
    
    @_spi(SendbirdInternal) public func connect(authToken: String?, sessionKey: String?, loginHandler: AuthUserHandler?) {
        guard let config = self.config else {
            let error = AuthClientError.notResolved.asAuthError
            loginHandler?(nil, error)
            return
        }
        
        let loginKey: LoginKey
        if let authToken = authToken {
            self.expirationHandler = UserSessionExpirationHandler(sessionToken: authToken, sessionHandler: sessionHandler, config: config)
            loginKey = .authToken(authToken)
        } else {
            self.expirationHandler = GuestSessionExpirationHandler(expiringSession: false)
            loginKey = .none
        }
        self.expirationHandler.delegate = self
        
        router.webSocketManager.connect(loginKey: loginKey, sessionKey: sessionKey, completionHandler: loginHandler)
    }
    
    @discardableResult
    @_spi(SendbirdInternal) public func reconnect(reconnectedBy: ReconnectingTrigger?) -> Bool {
        return router.webSocketManager.reconnect(sessionKey: self.session?.key, reconnectedBy: reconnectedBy)
    }

    @_spi(SendbirdInternal) public func logout() {
        reset()
    }
    
    private func reset() {
        userId = ""
        session = nil
        stateData?.clear()
    }
    
    // MARK: Injectable
    @_spi(SendbirdInternal) public func resolve(with dependency: (any Dependency)?) {
        self.dependency = dependency
    }
}

extension SessionManager: EventDelegate {
    @_spi(SendbirdInternal) public var priority: EventPriority { .highest } // higher than SendbirdChatMain (to update session from Connected event)
    
    @_spi(SendbirdInternal) public func didReceiveSBCommandEvent(command: SBCommand) async {
        switch command {
        case let event as SessionRefreshedEvent:
            if let sessionKey = event.sessionKey {
                self.session = Session(key: sessionKey, services: self.session?.services ?? [.chat, .feed])
            }
        case let event as SessionExpiredEvent:
            Logger.session.info("EXPR payload: \(String(describing: event.reason))")
            consumeError(event.reason?.asAuthError, expiresIn: event.expiresIn)
            
        default: break
        }
    }
    
    @_spi(SendbirdInternal) public func didReceiveInternalEvent(command: InternalEvent) {
        switch command {
        case is ConnectionStateEvent.Logout:
            logout()
        case let event as ConnectionStateEvent.Connected:
            stateData?.update(with: event.loginEvent)
            
            if let sessionKey = event.loginEvent.sessionKey,
               let services = event.loginEvent.services {
                let newSession = Session(key: sessionKey, services: services)
                
                if let currentSession = self.session, !currentSession.isDirty {
                    self.session = currentSession.isLargerScope(than: newSession) ? currentSession : newSession
                } else {
                    self.session = newSession
                }
            }
            
            eKey = event.loginEvent.eKey
            self.dependency?.commonSharedData.update(eKey: eKey)
            
            // TODO: (Ernest) default upload value?
            // Check if the default value of 100 is same as other platforms
            router.setUploadFileSizeLimit(event.loginEvent.appInfo?.uploadSizeLimit ?? 100)
            router.startPingTimer(pingInterval: event.loginEvent.pingInterval, watchdogInterval: event.loginEvent.watchdogInterval) { }
            
        case let event as ConnectionStateEvent.ReconnectionFailed:
            consumeError(event.error)
            
        case let event as ConnectionStateEvent.InternalDisconnected:
            if shouldRemoveCurrentUserCache(error: event.error) {
                self.localCachePreference.remove(forKey: LocalCachePreferenceKey.currentUser)
                self.stateData?.currentUser = nil
                
            }
        default: break
        }
    }
   
    @_spi(SendbirdInternal) public func shouldRemoveCurrentUserCache(error: AuthError?) -> Bool {
        return self.isLocalCachingEnabled == true && error?.shouldRemoveCurrentUserCache == true
    }
    
    @_spi(SendbirdInternal) public func consumeError(_ error: AuthError?, expiresIn: Int64? = nil) {
        switch error?.errorCode {
        case .accessTokenNotValid:
            expirationHandler.refreshSessionToken()
            
        case .sessionKeyExpired:
            session = nil
            expirationHandler.refreshSessionKey(
                shouldRetry: true,
                expiresIn: expiresIn
            )

        case .sessionTokenRevoked:
            sessionHandler.wasClosed()
            
        case .userDeactivated, .userNotExist:
            sessionHandler.wasClosed()
            
        default: break
        }
    }
}

extension SessionManager: SessionValidator {
    @_spi(SendbirdInternal) public func validateSession(isSessionRequired: Bool) throws -> String? {
        if !isSessionRequired { return nil }
        // for api

        // NOTE: return type could be nil later if we allow to authenticate via api and use
        // api without socket connection
        delegate?.sessionReconnectIfNeeded()
        
        if let sessionKey = session?.key, !sessionKey.isEmpty {
            return sessionKey
        }

        throw AuthClientError.connectionRequired.asAuthError
    }
    
    @_spi(SendbirdInternal) public func validateResponse<R>(_ response: R?, error: AuthError?) -> Bool {
        if let injectable = response as? Injectable {
            injectable.resolve(with: dependency)
        }
        
        consumeError(error)
        let isInvalidResponse = error?.errorCode == .sessionKeyExpired
        return !isInvalidResponse
    }
}

@_spi(SendbirdInternal) public protocol SessionManagerDelegate: AnyObject {
    func sessionKeyChanged(_ value: String?)
    func sessionReconnectRequired()
    func sessionReconnectIfNeeded()
    func sessionRefreshFailed()
}
