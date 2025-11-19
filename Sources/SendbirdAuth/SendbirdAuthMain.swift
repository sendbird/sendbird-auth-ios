//
//  SendbirdAuth.swift
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

package class SendbirdAuthMain: RequestHeaderDataSource, Dependency {
    private let userConnectionQueue = SafeSerialQueue(label: "com.sendbird.auth.state_manager_\(UUID().uuidString)")
    private let connectionOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    package var sessionDelegate: AuthSessionDelegate? {
        sessionHandler.delegate(forKey: DelegateKeys.session)
    }
    package var configTs: Int64? {
        SendbirdAuth.pref.value(forKey: PreferenceKey.configApiTs)
    }
    package var sessionManager: SessionManager

    package let config: SendbirdConfiguration
    package let service: QueueService
    package let stateData: ConnectionStateData
    package let requestQueue: RequestQueue
    package let router: CommandRouter
    package let eventDispatcher: EventDispatcher
    package let deviceConnectionManager: DeviceConnectionManager
    package let statManager: StatManager
    package let commonSharedData: CommonSharedData
    package let localCachePreference: LocalPreferences
    package let routerConfig: CommandRouterConfiguration
    package let sessionHandler: SessionEventBroadcaster
    
    package let isLocalCachingEnabled: Bool
    package let applicationId: String
    
    @InternalAtomic package var requestHeaderContext: RequestHeadersContext?
    package var logLevel: Logger.Level = .info
    package var appVersion: String?
    package var extensionVersions: [String: String]
    package var extensionSdkInfo: String?  // corresponds to `sbSdkUserAgent`. new since 4.8.5
    package var userConnectionManager: WebSocketManager {
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
    package var connectState: AuthWebSocketConnectionState {
        if stateData.applicationId.isEmpty {
            return .closed
        } else {
            return router.webSocketConnectionState
        }
    }
    
    package convenience init() {
        self.init(
            params: .init(
                applicationId: "",
                isLocalCachingEnabled: false
            )
        )
    }
    
    package init(
        params: InternalInitParams,
        statAPIClient: StatAPIClientable? = nil,
        webSocketEngine: ChatWebSocketEngine? = nil,
        httpClient: HTTPClientInterface? = nil,
        customRouterConfig: CommandRouterConfiguration? = nil,
        customSendbirdConfig: SendbirdConfiguration? = nil
    ) {
        Logger.setSDKVersion(SendbirdAuth.sdkVersion)
        
        let config = customSendbirdConfig ?? SendbirdConfiguration()
        
        let pref = SendbirdAuth.pref
        if let customAPIHost = params.customAPIHost {
            pref.set(value: customAPIHost, forKey: PreferenceKey.customAPIHost)
        }
        if let customWsHost = params.customWSHost {
            pref.set(value: customWsHost, forKey: PreferenceKey.customWsHost)
        }
        let apiHost = Configuration.apiHostURL(for: params.applicationId)
        let wsHost = Configuration.wsHostURL(for: params.applicationId)
        
        // INFO: initialize 과정에서는 service 를 고객이 설정할 수 없음. init 후 setCompletionHandlerDelegateQueue 호출되야 queue 변경 가능
        let service = QueueService()
        let dispatcher = EventDispatcher()
        
        let localCachePreference = LocalPreferences(suiteName: "com.sendbird.sdk.messaging.local_cache_preference")
        
        self.commonSharedData = CommonSharedData(eKey: nil)
        
        self.stateData = ConnectionStateData(
            applicationId: params.applicationId
        )
        
        let useNativeSocket: Bool = SendbirdAuth.pref.value(forKey: PreferenceKey.useNativeWS) ?? true
        let routerConfig = customRouterConfig ?? CommandRouterConfiguration(
            useNativeSocket: useNativeSocket,
            cachePolicy: .useProtocolCachePolicy,
            apiHost: apiHost, // only api/ws needs
            wsHost: wsHost
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
        placeHolderWebSocketManager.delegate = router
        
        let sessionHandler = SessionEventBroadcaster(service, mapTableValueOption: .strongMemory)
        let placeHolderSessionManager = SessionManager(
            applicationId: "",
            userId: "",
            router: router,
            sessionHandler: sessionHandler,
            isLocalCachingEnabled: params.isLocalCachingEnabled,
            localCachePreference: localCachePreference,
            config: config
        )
        self.sessionManager = placeHolderSessionManager
        
        let deviceConnectionManager = DeviceConnectionManager(
            commandRouter: router,
            sessionManager: sessionManager,
            eventDispatcher: dispatcher,
            broadcaster: ConnectionEventBroadcaster(service, mapTableValueOption: .strongMemory),
            networkBroadcaster: NetworkEventBroadcaster(service),
            internalBroadcaster: InternalConnectionEventBroadcaster(service)
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
        self.eventDispatcher = dispatcher
        
        self.deviceConnectionManager = deviceConnectionManager
        
        self.config = config
        self.service = service
        self.localCachePreference = localCachePreference
        self.applicationId = params.applicationId
        self.logLevel = params.logLevel
        self.appVersion = params.appVersion
        self.routerConfig = routerConfig
        self.isLocalCachingEnabled = params.isLocalCachingEnabled
        
        self.sessionHandler = sessionHandler
        
        self.extensionVersions = [:]
        
        self.requestHeaderContext = createRequestHeadersContext()
        
        Logger.setLoggerLevel(logLevel)
        
        SendbirdAuth.authDecoder.updateDependency(self)
        
        self.sessionManager.resolve(with: self)
        self.sessionManager.delegate = self
        
        self.router.resolve(with: self)
        self.requestQueue.resolve(with: self)
        
        placeHolderWebSocketManager.resolve(with: self)
        placeHolderWebSocketManager.requestHeaderDataSource = self
        router.requestHeaderDataSource = self
        sessionManager.requestHeaderDataSource = self
        
        self.statManager.resolve(with: self)
        httpClientForRouter.resolve(with: self)
        
        self.registerEventDelegates()
        
        self.deviceConnectionManager.startReachability()
    }
    
    /// Modules that use the `Auth` object can resolve all the modules that
    /// need to be newly resolved within their own module at once.
    package func resolveDependency(with dependency: some Dependency) {
        Logger.main.debug("Resolving dependency with \(String(describing: dependency))")
        
        self.sessionManager.resolve(with: dependency)
        self.router.resolve(with: dependency)
        self.requestQueue.resolve(with: dependency)
    }
}

// MARK: - EventDelegate
extension SendbirdAuthMain: EventDelegate {
    private func registerEventDelegates() {
        self.eventDispatcher.add(
            receivers: [
                deviceConnectionManager,
                requestQueue,
                statManager,
                self
            ]
        )
        self.eventDispatcher.add(
            receiver: sessionManager,
            forKey: "SendbirdAuth.SessionManager"
        )
    }
    
    package func didReceiveSBCommandEvent(command: SBCommand) async {
        switch command {
        case let event as SessionExpiredEvent:
            if event.reason?.asAuthError.shouldRevokeSession == true {
                disconnect()
            }
        default: break
        }
    }
    
    package func didReceiveInternalEvent(command: InternalEvent) {
        switch command {
        case is ConnectionStateEvent.Logout:
            reset()
            router.reset { }
            
        case is ConnectionStateEvent.ExternalDisconnected:
            deviceConnectionManager.logout()
            
        case let command as ConnectionStateEvent.Connected:
            let loginEvent = command.loginEvent
            
            SendbirdAuth.pref.set(
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
    package func reset() {
        stateData.clear()
        sessionManager.logout()
        requestQueue.stateData?.clear()
        router.apiClient.clear()
        
        deviceConnectionManager.logout()
        
        SendbirdAuth.pref.removeAll()
        localCachePreference.removeAll()
    }
    
    package func disconnect(isExplicit: Bool = false, completionHandler: VoidHandler? = nil) {
        Logger.main.debug("disconnect. currentUser: \(sessionManager.userId), services: \(String(describing: sessionManager.session?.services))")
        if sessionManager.session?.services == [.feed] {
            // If Websocket is not being used, call reset in order to clean up any resources from API Auth
            self.reset()
            completionHandler?()
        } else {
            // If Websocket is being used, Websocket state machine will call Logout and clean resources
            router.webSocketManager.disconnect(isExplicit: isExplicit, completionHandler: completionHandler)
        }
    }
    
    package func disconnectWebSocket(completionHandler: VoidHandler? = nil) {
        Logger.main.debug()
        router.webSocketManager.disconnectWebSocket(completionHandler: completionHandler)
    }
    
    @discardableResult
    package func reconnect(reconnectedBy: ReconnectingTrigger?) -> Bool {
        Logger.main.debug("reconnect by \(String(describing: reconnectedBy?.rawValue))")
        return sessionManager.reconnect(reconnectedBy: reconnectedBy)
    }
    
    package func sessionReconnectRequired() {
        reconnect(reconnectedBy: .refreshedSessionKey)
    }
    
    package func sessionReconnectIfNeeded() {
        if deviceConnectionManager.isForeground
            && !requestQueue.router.connected
            && !(userConnectionManager.state is ExternalDisconnectedState) {
            reconnect(reconnectedBy: .sessionValidation)
        }
    }
    
    package func sessionKeyChanged(_ value: String?) { }
    
    package func sessionRefreshFailed() {
        if router.webSocketManager.isReconnecting {
            deviceConnectionManager.broadcaster.failedReconnection()
            disconnect()
        }
    }
}

// MARK: - Connect
extension SendbirdAuthMain {
    package func connect(
        userId: String,
        accessToken: String? = nil,
        apiHost: String? = nil,
        wsHost: String? = nil,
        onPreparingConnection: @escaping () -> Void = {},
        completionHandler: AuthUserHandler? = nil
    ) {
        Logger.main.debug("applicationId: \(self.applicationId), userId: \(userId), useToken: \(accessToken != nil), apiHost: \(String(describing: apiHost)), wsHost: \(String(describing: wsHost))")
        
        // INFO: Custom hosts
        let pref = SendbirdAuth.pref
        if let apiHost {
            pref.set(value: apiHost, forKey: PreferenceKey.customAPIHost)
        } else {
            pref.remove(forKey: PreferenceKey.customAPIHost)
        }
        if let wsHost {
            pref.set(value: wsHost, forKey: PreferenceKey.customWsHost)
        } else {
            pref.remove(forKey: PreferenceKey.customWsHost)
        }
        
        guard !userId.isEmpty else {
            self.service {
                let err = AuthClientError.invalidParameter.asAuthError(
                    message: .emptyParameter("userId")
                )
                completionHandler?(nil, err)
            }
            return
        }
        
        guard !self.applicationId.isEmpty else {
            self.service {
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
            userId == cachedUser?.userId {
            self.userConnectionQueue.async {
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
    
    package func resetConnectionState(userId: String) {
        Logger.main.debug()
        // Create new session manager
        let sessionManager = SessionManager(
            applicationId: applicationId,
            userId: userId,
            router: router,
            sessionHandler: sessionHandler,
            isLocalCachingEnabled: isLocalCachingEnabled,
            localCachePreference: localCachePreference,
            config: config
        )
        
        self.sessionManager = sessionManager
        self.sessionManager.delegate = self
        self.sessionManager.resolve(with: self)
        self.sessionManager.requestHeaderDataSource = self
        self.requestQueue.sessionValidator = sessionManager
        
        // Create new websocket
        #if TESTCASE // For testing
        let websocketClient = router.webSocketManager.webSocketClient as? ChatWebSocketClient
        let engine = MockInstance.pop(key: .chatWebSocketEngine) ?? websocketClient?.getEngine()?.createNewWebSocketEngine()
        #else
        let engine: ChatWebSocketEngine? = nil
        #endif
        
        // Remove all delegates from the previous WebSocketManager
        router.webSocketManager.webSocketClient.delegates.removeAllObjects()
        
        let webSocketManager = WebSocketManager(
            userId: userId,
            queue: userConnectionQueue,
            eventDispatcher: eventDispatcher,
            requestHeaderDataSource: self,
            routerConfig: routerConfig,
            sendbirdConfig: config,
            webSocketEngine: engine
        )
        webSocketManager.delegate = router
        webSocketManager.resolve(with: self)
        router.webSocketManager = webSocketManager
        deviceConnectionManager.webSocketManager = router.webSocketManager
        
        self.eventDispatcher.add(receivers: [sessionManager, webSocketManager])
        self.deviceConnectionManager.sessionManager = sessionManager
    }
    
    private func connect(
        userId: String,
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
    package func authenticate(
        userId: String,
        authData: AuthData? = nil,
        apiHost: String? = nil,
        onPreparingAuthentication: @escaping () -> Void = {},
        completionHandler: AuthUserHandler? = nil
    ) {
        guard userId.hasElements else {
            self.service {
                let err = AuthClientError.invalidParameter.asAuthError(
                    message: .emptyParameter("userId")
                )
                completionHandler?(nil, err)
            }
            return
        }

        guard self.applicationId.hasElements else {
            self.service {
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
        authData: AuthData?,
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
                self.userConnectionQueue.async { [weak self] in
                    self?.resetConnectionState(userId: userId)
                    completionHandler(nil)
                }
            }
        }
    }

    private func authenticate(
        userId: String,
        authData: AuthData?,
        sessionKey: String?,
        apiHost: String?,
        completionHandler: AuthUserHandler?
    ) {
        // INFO: Custom hosts
        let pref = SendbirdAuth.pref
        if let apiHost {
            pref.set(value: apiHost, forKey: PreferenceKey.customAPIHost)
        } else {
            pref.remove(forKey: PreferenceKey.customAPIHost)
        }

        routerConfig.updateHost(apiHost: apiHost, wsHost: nil)
        sessionManager.authenticate(authData: authData, loginHandler: completionHandler)
    }
}

// MARK: - Configuration
package extension SendbirdAuthMain {
    struct Constants {
        package static let premiumFeatureList = "premium_feature_list"
        package static let fileUploadSizeLimit = "file_upload_size_limit"
        package static let emojiHash = "emoji_hash"
        package static let applicationAttributes = "application_attributes"
        package static let notifications = "notifications"
        package static let messageTemplate = "message_template"
        package static let aiAgent = "ai_agent"
        
        package static let extensionUIKit = "sb_uikit"
        package static let extensionSyncManager = "sb_syncmanager"
        package static let extensionSwiftUI = "sb_swiftui"
        
        package static let loginTimerHandlerKey = "login_timer_handler"
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
            Constants.aiAgent
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
        var results: [String] = [Self.systemName, "c\(SendbirdAuth.sdkVersion)"]
        
        if let syncManagerVersion = extensionVersions[Constants.extensionSyncManager] {
            results.append("s\(syncManagerVersion)")
        } else {
            results.append("")  // placeholder string for 's[version_syncmanager]'
        }
        
        if let uiKitVersion = extensionVersions[Constants.extensionUIKit] {
            results.append("u\(uiKitVersion)")
        } else {
            results.append("")  // placeholder string for 'u[version_uikit]'
        }
        
        // INFO: Jios 형태로 사용되는건 이제 사용되지 않고 SendbirdProduct 로 수집되는 데이터만 사용됨. SwiftUI 는 여기 추가하지 않음
        
        results.append("")  // placeholder string for 'o[device-os-platform]'
        
        return results.joined(separator: "/")
    }
    
    /// a more scalable version of sbUserAgent.
    /// SB-SDK-User-Agent: <key1>=<value1>&<key2>=<value2>...
    /// since: 4.8.5
    var sbSdkUserAgent: String {
        var version = ["main_sdk_info=chat/\(Self.systemName.lowercased())/\(sdkVersion)"]
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
            applicationId
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
            sdkVersion: sdkVersion,
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
            self.requestHeaderContext = createRequestHeadersContext()
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
        
        self.appVersion = version
        requestHeaderContext = createRequestHeadersContext()
    }
    
    func setSharedContainerIdentifier(_ identifier: String) {
        self.router.apiClient.sharedContainerIdentifier = identifier
    }
    
    func ekey() -> String? {
        return sessionManager.eKey
    }
}
