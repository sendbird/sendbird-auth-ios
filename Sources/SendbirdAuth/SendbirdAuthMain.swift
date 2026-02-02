//
//  SendbirdAuthMain.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/17/25.
//

import Foundation
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

@_spi(SendbirdInternal) public class SendbirdAuthMain: RequestHeaderDataSource, Dependency {
    private let userConnectionQueue = SafeSerialQueue(label: "com.sendbird.auth.state_manager_\(UUID().uuidString)")
    private let connectionOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    @_spi(SendbirdInternal) public var sessionDelegate: AuthSessionDelegate? {
        sessionHandler.delegate(forKey: DelegateKeys.session)
    }

    @_spi(SendbirdInternal) public var configTs: Int64? {
        preference.value(forKey: PreferenceKey.configApiTs)
    }

    @_spi(SendbirdInternal) public var sessionManager: SessionManager

    @_spi(SendbirdInternal) public let config: SendbirdConfiguration
    @_spi(SendbirdInternal) public let service: QueueService
    @_spi(SendbirdInternal) public let stateData: ConnectionStateData
    @_spi(SendbirdInternal) public let requestQueue: RequestQueue
    @_spi(SendbirdInternal) public let router: CommandRouter
    @_spi(SendbirdInternal) public let eventDispatcher: EventDispatcher
    @_spi(SendbirdInternal) public let deviceConnectionManager: DeviceConnectionManager
    @_spi(SendbirdInternal) public let statManager: StatManager
    @_spi(SendbirdInternal) public let commonSharedData: CommonSharedData
    @_spi(SendbirdInternal) public let localCachePreference: LocalPreferences
    @_spi(SendbirdInternal) public let routerConfig: CommandRouterConfiguration
    @_spi(SendbirdInternal) public let sessionHandler: SessionEventBroadcaster

    @_spi(SendbirdInternal) public let isLocalCachingEnabled: Bool
    @_spi(SendbirdInternal) public let applicationId: String

    /// Session provider for sharing session across multiple SDK instances.
    @_spi(SendbirdInternal) public private(set) var sessionProvider: SessionProvider?

    /// Instance-specific preferences (isolated per appId + apiHostUrl)
    @_spi(SendbirdInternal) public let preference: LocalPreferences

    #if DEBUG
        private var websocketEngine: (any ChatWebSocketEngine)? // For test
        @_spi(SendbirdInternal) public func injectEngineForTest(_ engine: any ChatWebSocketEngine) {
            websocketEngine = engine
        }
    #endif

    @InternalAtomic @_spi(SendbirdInternal) public var requestHeaderContext: RequestHeadersContext?
    @_spi(SendbirdInternal) public var logLevel: Logger.Level = .info
    @_spi(SendbirdInternal) public var appVersion: String?
    @_spi(SendbirdInternal) public var extensionVersions: [String: String]
    @_spi(SendbirdInternal) public var extensionSdkInfo: String? // corresponds to `sbSdkUserAgent`. new since 4.8.5
    @_spi(SendbirdInternal) public var mainSDKInfo: SendbirdSDKInfo?
    @_spi(SendbirdInternal) public var userConnectionManager: WebSocketManager {
        get {
            userConnectionQueue.sync {
                router.webSocketManager
            }
        }
        set {
            userConnectionQueue.async { [weak self] in
                guard let self = self else { return }
                self.router.webSocketManager = newValue
            }
        }
    }

    @_spi(SendbirdInternal) public var connectState: AuthWebSocketConnectionState {
        if stateData.applicationId.isEmpty {
            return .closed
        } else {
            return router.webSocketConnectionState
        }
    }

    @_spi(SendbirdInternal) public convenience init() {
        self.init(
            params: .init(
                applicationId: "",
                isLocalCachingEnabled: false
            )
        )
    }

    @_spi(SendbirdInternal) public init(
        params: InternalInitParams,
        statAPIClient: StatAPIClientable? = nil,
        webSocketEngine: (any ChatWebSocketEngine)? = nil,
        httpClient: HTTPClientInterface? = nil,
        customRouterConfig: CommandRouterConfiguration? = nil,
        customSendbirdConfig: SendbirdConfiguration? = nil
    ) {
        Logger.setSDKVersion(SendbirdAuth.sdkVersion)
        mainSDKInfo = params.mainSDKInfo

        let config = customSendbirdConfig ?? SendbirdConfiguration()

        // Create instance-specific preferences
        let instanceKey = InstanceRegistry.createKey(appId: params.applicationId, apiHostUrl: params.customAPIHost)
        let instancePref = LocalPreferences(suiteName: "com.sendbird.sdk.ios.\(instanceKey)")
        self.preference = instancePref

        if let customAPIHost = params.customAPIHost {
            instancePref.set(value: customAPIHost, forKey: PreferenceKey.customAPIHost)
        }
        if let customWsHost = params.customWSHost {
            instancePref.set(value: customWsHost, forKey: PreferenceKey.customWsHost)
        }
        let apiHost = Configuration.apiHostURL(for: params.applicationId, using: instancePref)
        let wsHost = Configuration.wsHostURL(for: params.applicationId, using: instancePref)

        // INFO: initialize 과정에서는 service 를 고객이 설정할 수 없음. init 후 setCompletionHandlerDelegateQueue 호출되야 queue 변경 가능
        let service = QueueService()
        let dispatcher = EventDispatcher()

        let localCachePreference = LocalPreferences(suiteName: "com.sendbird.sdk.messaging.local_cache_preference")

        commonSharedData = CommonSharedData(eKey: nil)

        stateData = ConnectionStateData(
            applicationId: params.applicationId
        )

        let useNativeSocket: Bool = instancePref.value(forKey: PreferenceKey.useNativeWS) ?? true
        let routerConfig = customRouterConfig ?? CommandRouterConfiguration(
            useNativeSocket: useNativeSocket,
            cachePolicy: .useProtocolCachePolicy,
            apiHost: apiHost, // only api/ws needs
            wsHost: wsHost,
            exceptionParser: params.exceptionParser
        )

        let placeHolderWebSocketManager = WebSocketManager(
            userId: "",
            queue: userConnectionQueue,
            eventDispatcher: dispatcher,
            requestHeaderDataSource: nil,
            routerConfig: routerConfig,
            sendbirdConfig: config,
            webSocketEngine: webSocketEngine
        )

        let httpClientForRouter = httpClient ?? HTTPClient(routerConfig: routerConfig)
        let router = CommandRouter(
            routerConfig: routerConfig,
            webSocketManager: placeHolderWebSocketManager,
            httpClient: httpClientForRouter,
            eventDispatcher: dispatcher
        )

        let sessionHandler = SessionEventBroadcaster(service, mapTableValueOption: .strongMemory)
        let placeHolderSessionManager = SessionManager(
            applicationId: "",
            userId: "",
            router: router,
            sessionHandler: sessionHandler,
            isLocalCachingEnabled: params.isLocalCachingEnabled,
            localCachePreference: localCachePreference,
            config: config,
            sessionProvider: params.sessionProvider
        )
        sessionManager = placeHolderSessionManager

        let deviceConnectionManager = DeviceConnectionManager(
            commandRouter: router,
            sessionManager: sessionManager,
            eventDispatcher: dispatcher,
            broadcaster: ConnectionEventBroadcaster(service, mapTableValueOption: .strongMemory),
            networkBroadcaster: NetworkEventBroadcaster(service),
            internalBroadcaster: InternalConnectionEventBroadcaster(service),
            instancePref: instancePref
        )

        let requestQueue = RequestQueue(
            commandRouter: router,
            sessionValidator: sessionManager
        )
        self.requestQueue = requestQueue

        let statManager = StatManager(
            apiClient: statAPIClient ?? StatAPIClient(requestQueue: requestQueue),
            isLocalCachingEnabled: params.isLocalCachingEnabled,
            configuration: config
        )

        self.router = router

        self.statManager = statManager
        eventDispatcher = dispatcher

        self.deviceConnectionManager = deviceConnectionManager

        self.config = config
        self.service = service
        self.localCachePreference = localCachePreference
        applicationId = params.applicationId
        logLevel = params.logLevel
        appVersion = params.appVersion
        self.routerConfig = routerConfig
        isLocalCachingEnabled = params.isLocalCachingEnabled
        self.sessionProvider = params.sessionProvider

        self.sessionHandler = sessionHandler

        extensionVersions = [:]

        requestHeaderContext = createRequestHeadersContext()

        Logger.setLoggerLevel(logLevel)

        SendbirdAuth.authDecoder.updateAuthDependency(self)

        sessionManager.resolve(with: self)
        sessionManager.delegate = self

        self.router.resolve(with: self)
        self.requestQueue.resolve(with: self)

        placeHolderWebSocketManager.resolve(with: self)
        placeHolderWebSocketManager.requestHeaderDataSource = self
        router.requestHeaderDataSource = self
        sessionManager.requestHeaderDataSource = self

        self.statManager.resolve(with: self)
        httpClientForRouter.resolve(with: self)

        registerEventDelegates()

        self.deviceConnectionManager.startReachability()
    }

    /// Modules that use the `Auth` object can resolve all the modules that
    /// need to be newly resolved within their own module at once.
    @_spi(SendbirdInternal) public func resolveDependency(with dependency: some Dependency) {
        Logger.main.debug("Resolving dependency with \(String(describing: dependency))")

        sessionManager.resolve(with: dependency)
        router.resolve(with: dependency)
        requestQueue.resolve(with: dependency)
    }
}

// MARK: - EventDelegate

extension SendbirdAuthMain: EventDelegate {
    private func registerEventDelegates() {
        eventDispatcher.add(
            receivers: [
                deviceConnectionManager,
                requestQueue,
                statManager,
                self,
            ]
        )
        eventDispatcher.add(
            receiver: sessionManager,
            forKey: "SendbirdAuth.SessionManager"
        )
    }

    @_spi(SendbirdInternal) public func didReceiveSBCommandEvent(command: SBCommand) async {
        switch command {
        case let event as SessionExpiredEvent:
            if event.reason?.asAuthError.shouldRevokeSession == true {
                disconnect()
            }
        default: break
        }
    }

    @_spi(SendbirdInternal) public func didReceiveInternalEvent(command: InternalEvent) {
        switch command {
        case is ConnectionStateEvent.Logout:
            reset()
            Task {
                // Originally, it doesn't wait for the reset to complete
                await router.reset()
            }

        case is ConnectionStateEvent.ExternalDisconnected:
            deviceConnectionManager.logout()

        case let command as ConnectionStateEvent.Connected:
            let loginEvent = command.loginEvent

            preference.set(
                value: loginEvent.appInfo?.useNativeWS ?? false,
                forKey: PreferenceKey.useNativeWS
            )

            if command.isReconnected == false {
                Logger.main.info("Start reachability")
                deviceConnectionManager.startReachability(host: routerConfig.apiHost)
            }

            if isLocalCachingEnabled {
                localCachePreference.set(value: loginEvent.user, forKey: LocalCachePreferenceKey.currentUser)
                localCachePreference.set(value: loginEvent.appInfo, forKey: LocalCachePreferenceKey.currentAppInfo)
                localCachePreference.set(value: loginEvent.reconnectConfiguration, forKey: LocalCachePreferenceKey.reconnectConfig)

                if let notificationEnabled: Bool = localCachePreference.value(forKey: LocalCachePreferenceKey.notificationEnabled) {
                    if notificationEnabled == false {
                        localCachePreference.set(value: loginEvent.appInfo?.notificationInfo?.isEnabled ?? false, forKey: LocalCachePreferenceKey.notificationEnabled)
                    }
                } else {
                    localCachePreference.set(value: loginEvent.appInfo?.notificationInfo?.isEnabled ?? false, forKey: LocalCachePreferenceKey.notificationEnabled)
                }
            }

        case is ConnectionStateEvent.Connecting:
            // Pre-initialize `apiClient`(HTTP) to prevent delays from cold-start
            router.apiClient.prefetch()

        case is ConnectionStateEvent.Reconnecting:
            // Pre-initialize `apiClient`(HTTP) to prevent delays from cold-start
            router.apiClient.prefetch()

        default: break
        }
    }
}

// MARK: - SessionManagerDelegate

extension SendbirdAuthMain: SessionManagerDelegate {
    @_spi(SendbirdInternal) public func reset() {
        stateData.clear()
        sessionManager.logout()
        requestQueue.stateData?.clear()
        router.apiClient.clear()

        deviceConnectionManager.logout()

        preference.removeAll()
        localCachePreference.removeAll()
    }

    @_spi(SendbirdInternal) public func disconnect(isExplicit: Bool = false, completionHandler: VoidHandler? = nil) {
        Logger.main.debug("disconnect. currentUser: \(sessionManager.userId), services: \(String(describing: sessionManager.session?.services))")
        if sessionManager.session?.services == [.feed] {
            // If Websocket is not being used, call reset in order to clean up any resources from API Auth
            reset()
            completionHandler?()
        } else {
            // If Websocket is being used, Websocket state machine will call Logout and clean resources
            router.webSocketManager.disconnect(isExplicit: isExplicit, completionHandler: completionHandler)
        }
    }

    @_spi(SendbirdInternal) public func disconnectWebSocket(completionHandler: VoidHandler? = nil) {
        Logger.main.debug()
        router.webSocketManager.disconnectWebSocket(completionHandler: completionHandler)
    }

    @discardableResult
    @_spi(SendbirdInternal) public func reconnect(reconnectedBy: ReconnectingTrigger?) -> Bool {
        Logger.main.debug("reconnect by \(String(describing: reconnectedBy?.rawValue))")
        return sessionManager.reconnect(reconnectedBy: reconnectedBy)
    }

    @_spi(SendbirdInternal) public func sessionReconnectRequired() {
        reconnect(reconnectedBy: .refreshedSessionKey)
    }

    @_spi(SendbirdInternal) public func sessionReconnectIfNeeded() {
        if deviceConnectionManager.isForeground
            && !requestQueue.router.connected
            && !(userConnectionManager.state is ExternalDisconnectedState)
        {
            reconnect(reconnectedBy: .sessionValidation)
        }
    }

    @_spi(SendbirdInternal) public func sessionKeyChanged(_: String?) {}

    @_spi(SendbirdInternal) public func sessionRefreshFailed() {
        if router.webSocketManager.isReconnecting {
            deviceConnectionManager.broadcaster.failedReconnection()
            disconnect()
        }
    }
}

// MARK: - Lifecycle

extension SendbirdAuthMain {
    /// Explicitly destroys this instance and removes it from the instances map
    @_spi(SendbirdInternal) public func destroy(completionHandler: VoidHandler? = nil) {
        disconnect { [weak self] in
            self?.reset()
            completionHandler?()
        }
    }
}

// MARK: - Connect

extension SendbirdAuthMain {
    @_spi(SendbirdInternal) public func connect(
        userId: String,
        accessToken: String? = nil,
        apiHost: String? = nil,
        wsHost: String? = nil,
        onPreparingConnection: @escaping () -> Void = {},
        completionHandler: AuthUserHandler? = nil
    ) {
        Logger.main.debug("applicationId: \(applicationId), userId: \(userId), useToken: \(accessToken != nil), apiHost: \(String(describing: apiHost)), wsHost: \(String(describing: wsHost))")

        // INFO: Custom hosts
        if let apiHost {
            preference.set(value: apiHost, forKey: PreferenceKey.customAPIHost)
        } else {
            preference.remove(forKey: PreferenceKey.customAPIHost)
        }
        if let wsHost {
            preference.set(value: wsHost, forKey: PreferenceKey.customWsHost)
        } else {
            preference.remove(forKey: PreferenceKey.customWsHost)
        }

        guard !userId.isEmpty else {
            service {
                let err = AuthClientError.invalidParameter.asAuthError(
                    message: .emptyParameter("userId")
                )
                completionHandler?(nil, err)
            }
            return
        }

        guard !applicationId.isEmpty else {
            service {
                Logger.session.error("Error: \(AuthClientError.invalidInitialization.asAuthError)")
                completionHandler?(nil, AuthClientError.invalidInitialization.asAuthError)
            }
            return
        }

        // The SDK v4 design requires that you retain one `UserConnectionManager` per userId.
        // To maintain this concept, create a new `UserConnectionManager` when SendbirdChatMain.connect is called.
        // However, there is a problem that if you create a new `UserConnectionManager`,
        // SDK lose the reference to the previous object.
        // Therefore, we use OperationQueue to do the connection task one by one without losing the reference to `UserConnectionManager`.
        connectionOperationQueue.addOperation(
            BlockingOperation(
                asyncTask: { [weak self] operation in

                    Logger.main.debug("adding to userConnectionQueue async")
                    self?.userConnectionQueue.async {
                        onPreparingConnection()

                        self?.prepareConnect(userId: userId, accessToken: accessToken, apiHost: apiHost, wsHost: wsHost) {
                            guard let self = self else { return }
                            self.connect(
                                userId: userId,
                                accessToken: accessToken,
                                sessionKey: Session.buildFromUserDefaults(for: userId)?.key,
                                apiHost: apiHost,
                                wsHost: wsHost,
                                completionHandler: completionHandler
                            )
                            operation.complete()
                        }
                    }
                })
        )
    }

    private func prepareConnect(
        userId: String,
        accessToken: String?,
        apiHost: String?,
        wsHost: String?,
        completionHandler: @escaping VoidHandler
    ) {
        Logger.main.debug("userId: \(userId), has authToken: \(accessToken != nil), apiHost: \(String(describing: apiHost)), wsHost: \(String(describing: wsHost))")

        Logger.main.debug("session userId: \(sessionManager.userId), currentUserId: \(userId)")
        guard sessionManager.userId != userId else {
            completionHandler()
            return
        }

        let cachedUser: AuthUser? = localCachePreference.value(forKey: LocalCachePreferenceKey.currentUser)

        if sessionManager.userId.isEmpty ||
            userId == cachedUser?.userId
        {
            userConnectionQueue.async {
                self.resetConnectionState(userId: userId)
                completionHandler()
            }
        } else {
            disconnect { [weak self] in
                self?.userConnectionQueue.async {
                    self?.resetConnectionState(userId: userId)
                    completionHandler()
                }
            }
        }
    }

    @_spi(SendbirdInternal) public func resetConnectionState(userId: String) {
        Logger.main.debug()
        // Create new session manager
        let sessionManager = SessionManager(
            applicationId: applicationId,
            userId: userId,
            router: router,
            sessionHandler: sessionHandler,
            isLocalCachingEnabled: isLocalCachingEnabled,
            localCachePreference: localCachePreference,
            config: config,
            sessionProvider: self.sessionProvider
        )

        self.sessionManager = sessionManager
        self.sessionManager.delegate = self
        self.sessionManager.resolve(with: self)
        self.sessionManager.requestHeaderDataSource = self
        requestQueue.sessionValidator = sessionManager

        // Create new websocket
        #if DEBUG // For testing
            let websocketClient = router.webSocketManager.webSocketClient as? ChatWebSocketClient
            let engine = websocketEngine ?? websocketClient?.getEngine().createNewWebSocketEngine()
        #else
            let engine: (any ChatWebSocketEngine)? = nil
        #endif

        let webSocketManager = WebSocketManager(
            userId: userId,
            queue: userConnectionQueue,
            eventDispatcher: eventDispatcher,
            requestHeaderDataSource: self,
            routerConfig: routerConfig,
            sendbirdConfig: config,
            webSocketEngine: engine
        )

        webSocketManager.resolve(with: self)
        router.webSocketManager = webSocketManager
        deviceConnectionManager.webSocketManager = router.webSocketManager

        eventDispatcher.add(receivers: [sessionManager, webSocketManager])
        deviceConnectionManager.sessionManager = sessionManager
    }

    private func connect(
        userId _: String,
        accessToken: String?,
        sessionKey: String?,
        apiHost: String?,
        wsHost: String?,
        completionHandler: AuthUserHandler?
    ) {
        Logger.main.debug()
        routerConfig.updateHost(apiHost: apiHost, wsHost: wsHost)
        sessionManager.connect(authToken: accessToken, sessionKey: sessionKey, loginHandler: completionHandler)
    }
}

// MARK: - Authenticate

extension SendbirdAuthMain {
    @_spi(SendbirdInternal) public func authenticate(
        userId: String,
        authData: AuthData? = nil,
        apiHost: String? = nil,
        onPreparingAuthentication: @escaping () -> Void = {},
        completionHandler: AuthUserHandler? = nil
    ) {
        guard userId.hasElements else {
            service {
                let err = AuthClientError.invalidParameter.asAuthError(
                    message: .emptyParameter("userId")
                )
                completionHandler?(nil, err)
            }
            return
        }

        guard applicationId.hasElements else {
            service {
                Logger.session.error("Error: \(AuthClientError.invalidInitialization.asAuthError)")
                completionHandler?(nil, AuthClientError.invalidInitialization.asAuthError)
            }
            return
        }

        // The SDK v4 design requires that you retain one `SessionManager` per userId.
        // To maintain this concept, create a new `SessionManager` when SendbirdChatMain. authenticate is called.
        // However, there is a problem that if you create a new `SessionManager`,
        // SDK lose the reference to the previous object.
        // Therefore, we use OperationQueue to do the connection task one by one without losing the reference to `SessionManager`.
        connectionOperationQueue.addOperation(BlockingOperation(asyncTask: { [weak self] operation in
            self?.userConnectionQueue.async {
                onPreparingAuthentication()

                self?.prepareAuthenticate(
                    userId: userId,
                    authData: authData
                ) { error in
                    guard let self = self else { return }

                    guard error == nil else {
                        completionHandler?(nil, error)
                        operation.complete()
                        return
                    }

                    self.authenticate(
                        userId: userId,
                        authData: authData,
                        sessionKey: self.sessionManager.session?.key,
                        apiHost: apiHost,
                        completionHandler: completionHandler
                    )
                    operation.complete()
                }
            }
        }))
    }

    private func prepareAuthenticate(
        userId: String,
        authData _: AuthData?,
        completionHandler: @escaping AuthErrorHandler
    ) {
        guard sessionManager.userId != userId else {
            completionHandler(nil)
            return
        }

        let cachedUser: AuthUser? = localCachePreference.value(forKey: LocalCachePreferenceKey.currentUser)

        if connectState == .open {
            let error = AuthClientError.requestFailed.asAuthError(message: .alreadyLoggedInDifferentUser)
            completionHandler(error)
            return
        }

        if sessionManager.userId.hasElements {
            disconnect { [weak self] in
                self?.userConnectionQueue.async {
                    self?.resetConnectionState(userId: userId)
                    completionHandler(nil)
                }
            }
        } else {
            if let cachedUserId = cachedUser?.userId, cachedUserId != userId {
                disconnect { [weak self] in
                    self?.userConnectionQueue.async {
                        self?.resetConnectionState(userId: userId)
                        completionHandler(nil)
                    }
                }
            } else {
                userConnectionQueue.async { [weak self] in
                    self?.resetConnectionState(userId: userId)
                    completionHandler(nil)
                }
            }
        }
    }

    private func authenticate(
        userId _: String,
        authData: AuthData?,
        sessionKey _: String?,
        apiHost: String?,
        completionHandler: AuthUserHandler?
    ) {
        // INFO: Custom hosts
        if let apiHost {
            preference.set(value: apiHost, forKey: PreferenceKey.customAPIHost)
        } else {
            preference.remove(forKey: PreferenceKey.customAPIHost)
        }

        routerConfig.updateHost(apiHost: apiHost, wsHost: nil)
        sessionManager.authenticate(authData: authData, loginHandler: completionHandler)
    }
}

// MARK: - Configuration

@_spi(SendbirdInternal) public extension SendbirdAuthMain {
    @_spi(SendbirdInternal) enum Constants {
        @_spi(SendbirdInternal) public static let premiumFeatureList = "premium_feature_list"
        @_spi(SendbirdInternal) public static let fileUploadSizeLimit = "file_upload_size_limit"
        @_spi(SendbirdInternal) public static let emojiHash = "emoji_hash"
        @_spi(SendbirdInternal) public static let applicationAttributes = "application_attributes"
        @_spi(SendbirdInternal) public static let notifications = "notifications"
        @_spi(SendbirdInternal) public static let messageTemplate = "message_template"
        @_spi(SendbirdInternal) public static let aiAgent = "ai_agent"
        @_spi(SendbirdInternal) public static let extensionUIKit = "sb_uikit"
        @_spi(SendbirdInternal) public static let extensionSyncManager = "sb_syncmanager"
        @_spi(SendbirdInternal) public static let extensionSwiftUI = "sb_swiftui"

        @_spi(SendbirdInternal) public static let loginTimerHandlerKey = "login_timer_handler"
    }

    var sdkVersion: String {
        SendbirdAuth.sdkVersion
    }

    var extraDataString: String {
        [
            Constants.premiumFeatureList,
            Constants.fileUploadSizeLimit,
            Constants.emojiHash,
            Constants.applicationAttributes,
            Constants.notifications,
            Constants.messageTemplate,
            Constants.aiAgent,
        ].joined(separator: ",")
    }

    static var systemVersion = {
        #if os(iOS)
            return UIDevice.current.systemVersion
        #else
            return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }()

    static var systemName = {
        #if os(iOS)
            return "iOS"
        #else
            return "macOS"
        #endif
    }()

    func getMimeType(_ file: Data?) -> String? {
        return file?.inferMimeType()
    }

    func setNetworkAwarenessReconnection(_ enabled: Bool) {
        deviceConnectionManager.useReachability = enabled
    }

    var sbUserAgent: String {
        var results: [String] = [Self.systemName]

        // If the mainSDKInfo is Chat, include chat version at the first position
        if mainSDKInfo?.product == .chat, let chatVersion = mainSDKInfo?.version {
            results.append("c\(chatVersion)")
        }

        results.append("a\(SendbirdAuth.sdkVersion)")

        if let syncManagerVersion = extensionVersions[Constants.extensionSyncManager] {
            results.append("s\(syncManagerVersion)")
        } else {
            results.append("") // placeholder string for 's[version_syncmanager]'
        }

        if let uiKitVersion = extensionVersions[Constants.extensionUIKit] {
            results.append("u\(uiKitVersion)")
        } else {
            results.append("") // placeholder string for 'u[version_uikit]'
        }

        // INFO: Jios 형태로 사용되는건 이제 사용되지 않고 SendbirdProduct 로 수집되는 데이터만 사용됨. SwiftUI 는 여기 추가하지 않음

        results.append("") // placeholder string for 'o[device-os-platform]'

        return results.joined(separator: "/")
    }

    /// a more scalable version of sbUserAgent.
    /// SB-SDK-User-Agent: <key1>=<value1>&<key2>=<value2>...
    /// since: 4.8.5
    var sbSdkUserAgent: String {
        let mainProduct = mainSDKInfo?.product.rawValue ?? SendbirdProduct.auth.rawValue
        let mainVersion = mainSDKInfo?.version ?? sdkVersion
        var version = ["main_sdk_info=\(mainProduct)/\(Self.systemName.lowercased())/\(mainVersion)"]
        version.append("device_os_platform=\(Self.systemName.lowercased())")
        version.append("os_version=\(Self.systemVersion)")

        if let extensionSdkInfo = extensionSdkInfo {
            version.append("extension_sdk_info=\(extensionSdkInfo)")
        }
        return version.joined(separator: "&")
    }

    var sendbirdHeader: String {
        var header = [
            Self.systemName,
            Self.systemVersion,
            sdkVersion,
            applicationId,
        ]

        if let appVersion = appVersion?.urlEncoded {
            header.append(appVersion)
        }

        return header.joined(separator: ",")
    }

    var userAgent: String { "Jios/\(sdkVersion)" }

    func createRequestHeadersContext() -> RequestHeadersContext {
        let includeUIKitConfig = (extensionVersions[Constants.extensionUIKit] != nil) || extensionVersions[Constants.extensionSwiftUI] != nil

        return RequestHeadersContext(
            deviceVersion: Self.systemVersion,
            sdkVersion: mainSDKInfo?.version ?? sdkVersion,
            applicationId: stateData.applicationId,
            appVersion: appVersion,
            extraDataString: extraDataString,
            userAgent: userAgent,
            sbUserAgent: sbUserAgent,
            sbSdkUserAgent: sbSdkUserAgent,
            sendbirdHeader: sendbirdHeader,
            isLocalCachingEnabled: isLocalCachingEnabled,
            isIncludePollDetails: config.pollIncludeDetails,
            inIncludeUIKitConfig: includeUIKitConfig
        )
    }

    func addExtension(_ key: String, version: String) {
        if key == Constants.extensionUIKit || key == Constants.extensionSyncManager || key == Constants.extensionSwiftUI {
            guard extensionVersions[key] != version else { return }

            Logger.main.debug("Set extension version: \(key): \(version), current: \(String(describing: extensionVersions[key]))")
            extensionVersions[key] = version
            requestHeaderContext = createRequestHeadersContext()
        }
    }

    func addSendbirdExtensions(extensions: [SendbirdSDKInfo], customData: [String: String]?) -> Bool {
        if extensions.isEmpty {
            return false
        }

        // validate extension versions (regex)
        if extensions.contains(where: { $0.validateVersionFormat() == false }) {
            Logger.main.error("Invalid version in `SendbirdSDKInfo`.")
            return false
        }

        // validate custom data
        if let customData = customData {
            for (key, value) in customData {
                if key.contains("=") || key.contains("&") || value.contains("=") || value.contains("&") {
                    Logger.main.error("Custom data in extensions should not contain '&' and '='.")
                    return false
                }
            }
        }

        // append extension versions for UIKit based SDKs (includeUIKitConfig)
        if let uikitExtension = extensions.first(where: {
            [.uikitChat, .swiftuiChat, .uikitLive].contains($0.product)
        }
        ) {
            extensionVersions[SendbirdAuthMain.Constants.extensionUIKit] = uikitExtension.version
        }

        // append extension SDKs
        var newExtensionSdkInfo = extensions
            .sorted(by: { $0.product.rawValue < $1.product.rawValue })
            .map { $0.toString() }
            .joined(separator: ",")

        // append custom data
        if let customData = customData {
            let customDataString = customData
                .sorted(by: { $0.key < $1.key })
                .map { "\($0)=\($1)" }
                .joined(separator: "&")
            newExtensionSdkInfo.append("&\(customDataString)")
        }
        guard extensionSdkInfo != newExtensionSdkInfo else { return false }
        Logger.main.debug("Set extension SDK info: \(newExtensionSdkInfo), current: \(String(describing: extensionSdkInfo))")

        extensionSdkInfo = newExtensionSdkInfo
        requestHeaderContext = createRequestHeadersContext()

        return true
    }

    func setAppVersion(version: String) {
        guard appVersion != version else { return }
        Logger.main.debug("Set app version: \(version), current: \(String(describing: appVersion))")

        appVersion = version
        requestHeaderContext = createRequestHeadersContext()
    }

    func setSharedContainerIdentifier(_ identifier: String) {
        router.apiClient.sharedContainerIdentifier = identifier
    }

    func ekey() -> String? {
        return sessionManager.eKey
    }
}
