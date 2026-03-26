//
//  SessionRuntime.swift
//  SendbirdAuth
//
//  Created by OpenAI Codex on 2026/03/26.
//

import Foundation

@_spi(SendbirdInternal) public protocol SessionRuntimeControlling: AnyObject {
    var session: Session? { get }
    var hasSessionDelegate: Bool { get }
    @discardableResult
    func reconnect(reconnectedBy: ReconnectingTrigger?) -> Bool
    func dispatchFeedRefresh()
}

@_spi(SendbirdInternal) public protocol SessionRuntimeDelegate: AnyObject {
    func sessionKeyChanged(_ value: String?)
    func sessionReconnectRequired()
    func sessionReconnectIfNeeded()
    func sessionRefreshFailed()
}

@_spi(SendbirdInternal) public class SessionRuntime: Injectable, SessionObserver, SessionRuntimeControlling {
    @_spi(SendbirdInternal) public static let minimumExpiresInForWSRefresh = 5

    @_spi(SendbirdInternal) public var state: SessionState {
        if expirationHandler.isRefreshingSession {
            return .refreshing
        } else if session != nil {
            return .connected
        } else {
            return .none
        }
    }

    @_spi(SendbirdInternal) public var session: Session? {
        get { sessionManager.session }
        set { sessionManager.session = newValue }
    }

    @_spi(SendbirdInternal) public var applicationId: String? { sessionManager.applicationId }
    @_spi(SendbirdInternal) public var userId: String? { sessionManager.userId }

    @InternalAtomic @_spi(SendbirdInternal) public var eKey: String?

    @_spi(SendbirdInternal) public let canRefreshSession: Bool

    @InternalAtomic private var isWaitingForExternalRefresh: Bool = false

    private var pendingDelegationError: AuthClientError?
    private var lastExpiredSession: Session?

    private let sessionManager: SessionManager
    private let board: SBTimerBoard

    @_spi(SendbirdInternal) public var sessionHandler: SessionEventBroadcaster
    @_spi(SendbirdInternal) public weak var delegate: SessionRuntimeDelegate?
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
    @_spi(SendbirdInternal) public weak var requestHeaderDataSource: RequestHeaderDataSource?

    @_spi(SendbirdInternal) public var hasSessionDelegate: Bool {
        sessionHandler.delegate(forKey: DelegateKeys.session) != nil
    }

    @_spi(SendbirdInternal) public init(
        sessionManager: SessionManager,
        router: CommandRouter,
        sessionHandler: SessionEventBroadcaster,
        isLocalCachingEnabled: Bool,
        localCachePreference: LocalPreferences,
        config: SendbirdConfiguration,
        canRefreshSession: Bool = true
    ) {
        self.sessionManager = sessionManager
        self.canRefreshSession = canRefreshSession
        self.sessionHandler = sessionHandler
        self.router = router
        self.board = SBTimerBoard(capacity: 1)
        self.expirationHandler = GuestSessionExpirationHandler(expiringSession: false)
        self.localCachePreference = localCachePreference
        self.isLocalCachingEnabled = isLocalCachingEnabled

        let queueLabel = "com.sendbird.chat.session.authenticate.\(sessionManager.userId ?? "uninitialized")"
        self.authenticateQueue = DispatchQueue(label: queueLabel)

        sessionManager.addSessionObserver(self)

        Logger.session.info("initialized - appId: \(applicationId ?? "nil"), userId: \(userId ?? "nil"), canRefreshSession: \(canRefreshSession)")
    }

    deinit {
        sessionManager.removeSessionObserver(self)
    }

    @_spi(SendbirdInternal) public func sessionDidChange(_ session: Session?) {
        delegate?.sessionKeyChanged(session?.key)

        if session != nil {
            lastExpiredSession = nil
        }

        guard let session else {
            return
        }

        guard claimExternalRefreshWait() else {
            return
        }

        pendingDelegationError = nil
        applyExternallyRefreshedSession(session)
    }

    @_spi(SendbirdInternal) public func sessionRefreshFailed() {
        guard claimExternalRefreshWait() else {
            return
        }

        let error = pendingDelegationError ?? AuthClientError.unknownError
        pendingDelegationError = nil
        handleRefreshFailure(error: error)
    }

    @_spi(SendbirdInternal) public func sessionRefreshRequested(for session: Session) {
        Logger.session.info("sessionRefreshRequested - canRefreshSession: \(canRefreshSession), isRefreshing: \(expirationHandler.isRefreshingSession)")

        guard canRefreshSession else {
            Logger.session.info("sessionRefreshRequested.delegateToExternal - canRefreshSession: \(canRefreshSession)")
            return
        }
        guard expirationHandler.isRefreshingSession == false else { return }
        if sessionManager.hasRefreshedSession(current: session) { return }
        expirationHandler.refreshSessionKey(shouldRetry: true, expiresIn: nil)
    }

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
                        self.expirationHandler = UserSessionExpirationHandler(
                            sessionToken: authData.authToken,
                            sessionHandler: self.sessionHandler,
                            config: config
                        )
                    } else {
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
                    useExpiringSession = self.requestHeaderDataSource?.isExpiringSession ?? false
                }
            } else {
                self.expirationHandler = GuestSessionExpirationHandler(expiringSession: true)
                useExpiringSession = true
            }
            self.expirationHandler.delegate = self
            Logger.session.info("authenticate.configure - userId: \(self.userId ?? "nil"), handler: \(type(of: self.expirationHandler))")

            guard let userId = self.userId else {
                self.isAuthenticating = false
                let error = AuthClientError.notResolved.asAuthError
                loginHandler?(nil, error)
                return
            }

            let authenticateRequest = AuthenticateRequest(
                userId: userId,
                applicationId: stateData.applicationId,
                authToken: authData?.authToken,
                expiringSession: useExpiringSession,
                requestHeaderDataSource: self.requestHeaderDataSource,
                includeLOGI: true,
                useLocalCache: self.isLocalCachingEnabled
            )

            self.router.send(request: authenticateRequest, sessionKey: nil) { [weak self] response, error in
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
        Logger.session.info("connect.configure - userId: \(userId ?? "nil"), handler: \(type(of: expirationHandler))")

        router.webSocketManager.connect(loginKey: loginKey, sessionKey: sessionKey, completionHandler: loginHandler)
    }

    @discardableResult
    @_spi(SendbirdInternal) public func reconnect(reconnectedBy: ReconnectingTrigger?) -> Bool {
        router.webSocketManager.reconnect(sessionKey: session?.key, reconnectedBy: reconnectedBy)
    }

    @_spi(SendbirdInternal) public func logout() {
        reset()
    }

    @_spi(SendbirdInternal) public func dispatchFeedRefresh() {
        guard let session,
              session.services.count == 1,
              session.services.contains(.feed) else { return }

        router.eventDispatcher.dispatch(command: AuthenticationStateEvent.Refresh())
    }

    func submitRefreshedSession(_ newSession: Session) -> Bool {
        sessionManager.submitRefreshedSession(newSession)
    }

    func broadcastSessionRefreshFailed() {
        sessionManager.notifySessionRefreshFailed()
    }

    func handleRefreshFailure(error: AuthClientError) {
        sessionHandler.didHaveError(error.asAuthError)
        router.eventDispatcher.dispatch(command: SessionExpirationEvent.RefreshFailed())
    }

    private func claimExternalRefreshWait() -> Bool {
        var wasWaiting = false
        $isWaitingForExternalRefresh.atomicMutate { value in
            wasWaiting = value
            value = false
        }
        return wasWaiting
    }

    private func reset() {
        board.stopAll()
        isWaitingForExternalRefresh = false
        pendingDelegationError = nil
        lastExpiredSession = nil
        session = nil
        sessionManager.clear()
        stateData?.clear()
    }

    func delegateRefreshToExternalSDK(error: AuthClientError) {
        Logger.session.info("delegateRefreshToExternalSDK - error: \(error), userId: \(userId ?? "nil")")
        let expiredSession = sessionManager.loadSession() ?? session ?? lastExpiredSession
        lastExpiredSession = nil

        guard let expiredSession else {
            handleRefreshFailure(error: error)
            return
        }

        isWaitingForExternalRefresh = true
        pendingDelegationError = error
        let accepted = sessionManager.requestSessionRefresh(for: expiredSession)

        if !accepted {
            isWaitingForExternalRefresh = false
            pendingDelegationError = nil
            handleRefreshFailure(error: error)
        }
    }

    @_spi(SendbirdInternal) public func resolve(with dependency: (any Dependency)?) {
        self.dependency = dependency
    }
}

extension SessionRuntime: EventDelegate {
    @_spi(SendbirdInternal) public var priority: EventPriority { .highest }

    @_spi(SendbirdInternal) public func didReceiveSBCommandEvent(command: SBCommand) async {
        switch command {
        case let event as SessionRefreshedEvent:
            if let sessionKey = event.sessionKey {
                let newSession = Session(key: sessionKey, services: self.session?.services ?? [.chat, .feed])
                self.session = newSession
            }
        case let event as SessionExpiredEvent:
            Logger.session.info("EXPR payload: \(String(describing: event.reason))")
            consumeError(event.reason?.asAuthError, expiresIn: event.expiresIn)
        default:
            break
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
                    let sessionToSet = currentSession.isLargerScope(than: newSession) ? currentSession : newSession
                    self.session = sessionToSet
                } else {
                    self.session = newSession
                }
            }

            eKey = event.loginEvent.eKey
            self.dependency?.commonSharedData.update(eKey: eKey)

            router.setUploadFileSizeLimit(event.loginEvent.appInfo?.uploadSizeLimit ?? 100)
            router.startPingTimer(pingInterval: event.loginEvent.pingInterval, watchdogInterval: event.loginEvent.watchdogInterval) { }

        case let event as ConnectionStateEvent.ReconnectionFailed:
            consumeError(event.error)

        case let event as ConnectionStateEvent.InternalDisconnected:
            if shouldRemoveCurrentUserCache(error: event.error) {
                self.localCachePreference.remove(forKey: LocalCachePreferenceKey.currentUser)
                self.stateData?.currentUser = nil
            }
        default:
            break
        }
    }

    @_spi(SendbirdInternal) public func shouldRemoveCurrentUserCache(error: AuthError?) -> Bool {
        self.isLocalCachingEnabled == true && error?.shouldRemoveCurrentUserCache == true
    }

    @_spi(SendbirdInternal) public func consumeError(_ error: AuthError?, expiresIn: Int64? = nil) {
        switch error?.errorCode {
        case .accessTokenNotValid:
            Logger.session.info("consumeError.accessTokenNotValid - errorCode: \(error?.code ?? 0)")
            expirationHandler.refreshSessionToken()

        case .sessionKeyExpired:
            Logger.session.info("consumeError.sessionKeyExpired - errorCode: \(error?.code ?? 0), expiresIn: \(expiresIn.map { String($0) } ?? "nil")")
            if let currentSession = session,
               sessionManager.hasRefreshedSession(current: currentSession) {
                Logger.session.info("consumeError.sessionKeyExpired.skipAlreadyRefreshed")
                return
            }

            if let session {
                self.lastExpiredSession = session
            }
            self.session = nil
            expirationHandler.refreshSessionKey(
                shouldRetry: true,
                expiresIn: expiresIn
            )

        case .sessionTokenRevoked:
            Logger.session.info("consumeError.sessionTokenRevoked - errorCode: \(error?.code ?? 0)")
            sessionHandler.wasClosed()

        case .userDeactivated, .userNotExist:
            Logger.session.info("consumeError.userClosed - errorCode: \(error?.code ?? 0)")
            sessionHandler.wasClosed()

        default:
            break
        }
    }
}

extension SessionRuntime: SessionValidator {
    @_spi(SendbirdInternal) public func validateSession(isSessionRequired: Bool) throws -> String? {
        if !isSessionRequired { return nil }

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
