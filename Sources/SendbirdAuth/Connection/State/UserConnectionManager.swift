//
//  UserConnectionManager.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation

@_spi(SendbirdInternal) public typealias ConnectionContext = WebSocketContext

@_spi(SendbirdInternal) public typealias WebSocketContext = WebSocketDataSource & WebSocketActionable & Injectable

@_spi(SendbirdInternal) public protocol WebSocketDataSource: AnyObject {
    var configForWebSocket: SendbirdConfiguration? { get }
    var serviceForWebSocket: QueueService? { get }
    var dataSourceForWebSocket: ConnectionStateData? { get }
    
    var eventDispatcher: EventDispatcher { get }
    var userId: String { get }
    var state: ConnectionStatable { get }
    var connectionRetryCount: Int { get }
    var reconnectionTryCount: Int { get }
    var hostURL: String { get }
    var netStatus: Reachability.Connection { get }
    
    /// Should be non-nil once connect() was explicitly called.
    /// - Since: 4.34.0
    var loginKey: LoginKey? { get }
    
    func notifyNewConnectionStarted()
    func notifyNewReconnectionStarted()
    func notifyConnectionFailed()
    func notifyReconnectionAttempt()
}

@_spi(SendbirdInternal) public protocol WebSocketActionable: AnyObject {
    func changeState(to nextState: ConnectionStatable)
    func createWebSocketURL(userId: String) -> String
    
    func connectSocket(url: String, accessToken: String?, sessionKey: String?)
    func disconnectSocket()
}

@_spi(SendbirdInternal) public protocol WebSocketManagerDelegate: AnyObject {
    func didReceiveMessage(_ message: String)
}

@_spi(SendbirdInternal) public typealias UserConnectionManager = WebSocketManager
@_spi(SendbirdInternal) public class WebSocketManager {
    // MARK: Injectable
    @DependencyWrapper private var dependency: Dependency?
    private var service: QueueService? { dependency?.service }
    @_spi(SendbirdInternal) public var stateData: ConnectionStateData? { dependency?.stateData }
    @_spi(SendbirdInternal) public var config: SendbirdConfiguration? { dependency?.config }
    private var statManager: StatManager? { dependency?.statManager }
    
    /// Should be non-nil once connect() was explicitly called.
    /// - Since: 4.34.0
    @_spi(SendbirdInternal) public var loginKey: LoginKey? = nil

    @InternalAtomic @_spi(SendbirdInternal) public var state: ConnectionStatable = InitializedState() {
        didSet {
            Logger.session.info("State transition \(oldValue) -> \(state)")
#if !RELEASE
            $previousStates.atomicMutate {
                $0.append(type(of: oldValue))
            }
#endif
            // TODO: 같은 state일때도 process가 여러번 불필요하게 호출될 수 있음 (connecting -> connecting 하면 지금 연결중인 소켓 끊고 다시 맺어져서 불필요한 오버헤드 생김). 근데 reconnecting일때 reconnect 호출하면 끊었다 재연결하는 로직을 이걸로 해결하고 있어서 나중에 전체적으로 코드 파악 후 수정 필요
            state.process(context: self)
        }
    }
    
#if !RELEASE
    @InternalAtomic @_spi(SendbirdInternal) public var previousStates: [ConnectionStatable.Type] = []
#endif
    
    @_spi(SendbirdInternal) public let eventDispatcher: EventDispatcher
    
    @_spi(SendbirdInternal) public var routerConfig: CommandRouterConfiguration {
        get async {
            await webSocketClient.routerConfig
        }
    }
    private let initialRouterConfig: CommandRouterConfiguration
    
    @_spi(SendbirdInternal) public func performOnCompletionQueue(_ block: (() -> Void)?) {
        service?.performOnCompletionQueue(block)
    }
    
    @_spi(SendbirdInternal) public var connectionRetryCount: Int {
        statManager?.connectionRetryCount ?? 0
    }
    @_spi(SendbirdInternal) public var reconnectionTryCount: Int {
        statManager?.reconnectionTryCount ?? 0
    }
    
    @_spi(SendbirdInternal) public var hostURL: String {
        statManager?.wsOpenedEvent?.hostURL ?? ""
    }
    
    @_spi(SendbirdInternal) public weak var delegate: WebSocketManagerDelegate?
    
    @_spi(SendbirdInternal) public var connectionState: AuthWebSocketConnectionState {
        queue.sync {
            if isConnecting || isReconnecting {
                return .connecting
            } else if isConnected /*session open*/ {
                return .open
            } else {
                return .closed
            }
        }
    }
    
    @_spi(SendbirdInternal) public let userId: String
    
    @_spi(SendbirdInternal) public private(set) var netStatus: Reachability.Connection = .unavailable
    
    @_spi(SendbirdInternal) public func changeNetworkStatus(to status: Reachability.Connection) {
        netStatus = status
        
        if status == .unavailable {
            networkDisconnected()
        }
    }
    
    @_spi(SendbirdInternal) public let queue: SafeSerialQueue
    private var webSocketEventTask: Task<Void, Never>? // stream consumption
    // !!!: Shouldn't it be much more strict?
    
    @_spi(SendbirdInternal) public init(
        userId: String,
        queue: SafeSerialQueue,
        eventDispatcher: EventDispatcher,
        requestHeaderDataSource: RequestHeaderDataSource?,
        routerConfig: CommandRouterConfiguration,
        sendbirdConfig: SendbirdConfiguration,
        webSocketEngine: (any ChatWebSocketEngine)?
    ) {
        Logger.socket.debug("userId: \(userId)")
        self.userId = userId
        self.queue = queue
        self.eventDispatcher = eventDispatcher
        
        self.requestHeaderDataSource = requestHeaderDataSource
        
        self.initialRouterConfig = routerConfig
        self.webSocketClient = ChatWebSocketClient(
            routerConfig: routerConfig,
            sendbirdConfig: sendbirdConfig,
            webSocketEngine: webSocketEngine
        )
        
        // Start consuming websocket events
        // 나중에 actor base로 리팩하면서 Engine처럼 바뀔 거임
        Task { [weak self] in
            guard let self else { return }
            await self.startListeningWebSocketEvents(from: self.webSocketClient)
        }
    }
    
    /// Avoid changing it directly. Use `setNewWebSocketClient` method instead.
    @InternalAtomic private(set) var webSocketClient: any ChatWebSocketClientInterface
    @_spi(SendbirdInternal) public weak var requestHeaderDataSource: RequestHeaderDataSource?
    
    @_spi(SendbirdInternal) public func createWebSocketURL(
        userId: String
    ) -> String {
        
        let paramsBuilder = RequestHeadersBuilder()
        
        paramsBuilder.append(key: "p", value: "iOS")
        paramsBuilder.append(key: "user_id", value: userId.urlEncoded)
        
        if let requestHeaderContext = requestHeaderDataSource?.requestHeaderContext {
            paramsBuilder.append(key: "pv", value: requestHeaderContext.deviceVersion)
            paramsBuilder.append(key: "sv", value: requestHeaderContext.sdkVersion)
            paramsBuilder.append(key: "ai", value: requestHeaderContext.applicationId)
            paramsBuilder.append(key: "av", value: requestHeaderContext.appVersion?.urlEncoded)
            paramsBuilder.append(key: "include_extra_data", value: requestHeaderContext.extraDataString)
            paramsBuilder.append(key: "SB-User-Agent", value: requestHeaderContext.sbUserAgent.urlEncoded)
            paramsBuilder.append(key: "SB-SDK-User-Agent", value: requestHeaderContext.sbSdkUserAgent.urlEncoded)
            paramsBuilder.append(key: "include_poll_details", value: requestHeaderContext.isIncludePollDetails)
            paramsBuilder.append(key: "expiring_session", value: requestHeaderDataSource?.isExpiringSession ?? false)
            paramsBuilder.append(key: "use_local_cache", value: requestHeaderContext.isLocalCachingEnabled)
            paramsBuilder.append(key: "pmce", value: true)
            paramsBuilder.append(key: "uikit_config", value: requestHeaderContext.inIncludeUIKitConfig)
            paramsBuilder.append(key: "config_ts", value: "\(requestHeaderDataSource?.configTs ?? 0)")
        } else {
            Logger.socket.info("requestHeaderContext must not be nil")
        }
        
        let params = paramsBuilder.buildString()
        Logger.main.debug("ws request: \(self.initialRouterConfig.wsHost)/?\(params)")
        
        return self.initialRouterConfig.wsHost + "/?" + params
    }
    
    // MARK: - private
    /// Sent only when the socket is in a connected state
    private func dispatchDisconnectEventIfConnected(
        errorType: AuthError?,
        reasonType: WebSocketDisconnectedReason
    ) {
        guard isConnected else {
            return
        }
        
        eventDispatcher.dispatch(
            command: WebSocketStatEvent.WebSocketDisconnectEvent(
                error: errorType,
                reason: reasonType
            )
        )
    }
    
    // MARK: Injectable
    @_spi(SendbirdInternal) public func resolve(with dependency: (any Dependency)?) {
        self.dependency = dependency
    }
}

// Removed ChatWebSocketClientDelegate conformance; using event stream instead.

// MARK: - Event Stream Consumption
extension WebSocketManager {
    private func handleWebSocketEvent(_ event: WebSocketClientEvent) async {
        switch event {
        case .started:
            Logger.socket.debug("started")
            
            eventDispatcher.dispatch(
                command: WebSocketStatEvent.WebSocketStartEvent()
            )
            
        case .opened:
            Logger.socket.debug("opened")
            
            guard let sentRequest = await webSocketClient.currentRequest else {
                return
            }
            
            eventDispatcher.dispatch(
                command: WebSocketStatEvent.WebSocketOpenedEvent(
                    hostURL: sentRequest.url?.host ?? "",
                    openedTimestampMs: Date().milliSeconds
                )
            )
            
            queue.async {
                self.state.didSocketOpen(context: self)
            }
            
        case .connectionFailed(let error):
            Logger.socket.debug("connection failed with \(String(describing: error))")
            let authError = AuthClientError.webSocketConnectionFailed.asAuthError(
                message: error.localizedDescription,
                extraUserInfo: (error as NSError).userInfo
            )
            
            if let sentRequest = await webSocketClient.currentRequest {
                eventDispatcher.dispatch(
                    command: WebSocketStatEvent.WebSocketFailedEvent(
                        hostURL: sentRequest.url?.host ?? "",
                        code: authError.code,
                        reason: authError.debugDescription
                    )
                )
            }
            
            queue.async {
                self.state.didSocketFail(context: self, error: authError)
            }
            
        case let .closed(code, reason):
            Logger.socket.debug("close with \(code), reason: \(reason ?? "")")
            
            if await webSocketClient.currentRequest != nil {
                // This case usually means watch dog timeout
                if code == .noStatusReceived {
                    dispatchDisconnectEventIfConnected(
                        errorType: AuthClientError.networkError.asAuthError(),
                        reasonType: .pingPongTimeout
                    )
                } else {
                    dispatchDisconnectEventIfConnected(
                        errorType: AuthClientError.webSocketConnectionClosed.asAuthError(),
                        reasonType: .otherReason(closeCode: code)
                    )
                }
            }

            queue.async {
                self.state.didSocketClose(context: self, code: code)
            }
            
        case .received(let message):
            Logger.socket.debug("received \(message)")
            delegate?.didReceiveMessage(message)
            
        case .timerExpired(let timerType):
            Logger.socket.debug("Timer expired for \(timerType)")
            
            let request = BaseWSRequest<DefaultResponse>(
                commandType: .ping,
                requestId: nil,
                body: .param([.id: Date().milliSeconds])
            )
            try? await webSocketClient.send(request: request)
        }
    }
    
    private func changeWebSocketClient(_ newClient: any ChatWebSocketClientInterface) async {
        let oldClient = webSocketClient
        guard newClient !== oldClient else {
            return
        }
        
        let prepare = {
#if DEBUG
            // INFO: InterceptableMocking 객체로 교체하는 케이스는 기존 engine 을 사용하기때문에 disconnect 안함
            if newClient is ChatWebSocketClient {
                await oldClient.forceDisconnect()
            }
            return
#else
            await oldClient.forceDisconnect()
#endif
        }
        
        await prepare()
        self.webSocketClient = newClient
        
        // restart stream consumption for new client
        await startListeningWebSocketEvents(from: newClient)
    }
    
    private func stopListeningWebSocketEvents(needBroadcast: Bool = false) async {
        webSocketEventTask?.cancel()
        webSocketEventTask = nil
        
        await webSocketClient.disconnect()
    }
    
    private func startListeningWebSocketEvents(from client: some ChatWebSocketClientInterface) async {
        webSocketEventTask?.cancel()

        let clientStream = await client.makeStream()
        webSocketEventTask = Task { [weak self] in
            for await event in clientStream {
                guard let self else { return }
                await self.handleWebSocketEvent(event)
            }
        }
    }
    
}

extension WebSocketManager: EventDelegate {
    
    @_spi(SendbirdInternal) public func didReceiveSBCommandEvent(command: SBCommand) async {
        switch command {
        case let command as LoginEvent:
            queue.async {
                self.state.didReceiveLOGI(context: self, command: command)
            }
        case let command as BusyEvent:
            queue.async {
                self.state.didReceiveBUSY(context: self, command: command)
            }
        default: break
        }
    }
    
    @_spi(SendbirdInternal) public func didReceiveInternalEvent(command: InternalEvent) {
        // do-nothing
    }
}

extension WebSocketManager: ConnectionContext {
    @_spi(SendbirdInternal) public var configForWebSocket: SendbirdConfiguration? { self.config }
    @_spi(SendbirdInternal) public var serviceForWebSocket: QueueService? { self.service }
    @_spi(SendbirdInternal) public var dataSourceForWebSocket: ConnectionStateData? { self.stateData }
    
    @_spi(SendbirdInternal) public var isConnecting: Bool { state is ConnectingState }
    @_spi(SendbirdInternal) public var isReconnecting: Bool { state is ReconnectingState }
    @_spi(SendbirdInternal) public var isConnected: Bool { state is ConnectedState }
    @_spi(SendbirdInternal) public var isDisconnected: Bool { state is LogoutState || state is InternalDisconnectedState }
    
    // NOTE: should not be called outside of state machine due to
    // deadlock on sync
    @_spi(SendbirdInternal) public func changeState(to nextState: ConnectionStatable) {
        Logger.session.verbose("\(state) to \(nextState)")
        state = nextState
    }
    
    @_spi(SendbirdInternal) public func connect(loginKey: LoginKey, sessionKey: String?, completionHandler: AuthUserHandler?) {
        self.loginKey = loginKey
        
        queue.async {
            Logger.socket.debug("connect: \(loginKey)")
            self.state.connect(
                context: self,
                loginKey: loginKey,
                sessionKey: sessionKey,
                userHandler: completionHandler
            )
        }
    }
    
    @_spi(SendbirdInternal) public func disconnect(isExplicit: Bool = false, completionHandler: VoidHandler? = nil) {
        if isExplicit {
            self.dispatchDisconnectEventIfConnected(
                errorType: nil,
                reasonType: .explicitDisconnect
            )
        }
        
        queue.async {
            Logger.socket.debug("disconnect. currentUser: \(self.userId)")
            self.state.disconnect(
                context: self,
                completionHandler: completionHandler
            )
        }
    }
    
    @_spi(SendbirdInternal) public func disconnectWebSocket(completionHandler: VoidHandler? = nil) {
        self.dispatchDisconnectEventIfConnected(
            errorType: nil,
            reasonType: .explicitDisconnectWebSocket
        )
        
        queue.async {
            Logger.socket.debug("disconnectWebSocket. currentUser: \(self.userId)")
            self.state.disconnectWebSocket(
                context: self,
                completionHandler: completionHandler
            )
        }
    }
    
    @_spi(SendbirdInternal) public func enterBackground(completionHandler: VoidHandler? = nil) {
        self.dispatchDisconnectEventIfConnected(
            errorType: AuthClientError.webSocketConnectionClosed.asAuthError,
            reasonType: .background
        )
        
        queue.async {
            self.state.didEnterBackground(context: self)
            completionHandler?()
        }
    }
    
    @_spi(SendbirdInternal) public func networkDisconnected(completionHandler: VoidHandler? = nil) {
        self.dispatchDisconnectEventIfConnected(
            errorType: AuthClientError.networkError.asAuthError,
            reasonType: .networkDisconnected
        )
    }
    
    @discardableResult
    @_spi(SendbirdInternal) public func reconnect(sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
        Logger.socket.debug("reconnect hasSessionKey: \(sessionKey != nil). currentUser: \(self.userId), by: \(String(describing: reconnectedBy?.rawValue))")
        
        if reconnectedBy == .manual {
            dispatchDisconnectEventIfConnected(errorType: nil, reasonType: .explicitReconnect)
        }
        
        return queue.sync {
            print("WebSocketManager.reconnect() > queue.sync { state.reconnect } / state=\(state) ⭐️")
            return state.reconnect(
                context: self,
                sessionKey: sessionKey,
                reconnectedBy: reconnectedBy
            )
        }
    }
    
    @_spi(SendbirdInternal) public func connectSocket(url: String, accessToken: String?, sessionKey: String?) {
        // TODO: Shutdown websocket client silently
        // This will trigger websocket disconnectd event, and may cause changes in the state machine.
        // Is it possible to disconnect the websocket client and discard it immediately?
        // P3
        queue.async {
            Task { [weak self] in
                guard let self else {
                    return
                }
                let state = await self.webSocketClient.state
                if state != .closed {
                    // Don't need to broadcast disconnection event here,
                    // as the new connection event will be broadcasted right after this.
                    await stopListeningWebSocketEvents()
                    await self.webSocketClient.disconnect()
                }

                Logger.user.debug("current socket client state: \(state.rawValue)")
                let newClient = await self.webSocketClient.createNewClient()
                await self.changeWebSocketClient(newClient)
                
                await self.webSocketClient.connect(
                    with: url,
                    accessToken: accessToken,
                    sessionKey: sessionKey
                )
            }
        }
    }
    
    @_spi(SendbirdInternal) public func disconnectSocket() {
        queue.async {
            Task { [self] in
                Logger.socket.debug("currentUser: \(self.userId)")
                await self.webSocketClient.disconnect()
            }
        }
    }
    
    @_spi(SendbirdInternal) public func notifyNewConnectionStarted() {
        statManager?.connectionId = UUID().uuidString
        statManager?.connectionRetryCount = 0
    }
    
    @_spi(SendbirdInternal) public func notifyNewReconnectionStarted() {
        statManager?.connectionId = UUID().uuidString
        statManager?.reconnectionTryCount = 0
    }
    
    @_spi(SendbirdInternal) public func notifyConnectionFailed() {
        statManager?.connectionRetryCount += 1
    }
    
    @_spi(SendbirdInternal) public func notifyReconnectionAttempt() {
        statManager?.reconnectionTryCount += 1
    }
    
    // MARK: - Temp async methods
    func disconnectSocket() async {
        // TODO: Add seiral runner
        Logger.socket.debug("currentUser: \(self.userId)")
        await self.webSocketClient.disconnect()
    }
}

// MARK: - Temporary WebSocketManager Indirection Wrappers
extension WebSocketManager {
    func sendWS<R: WSRequestable>(_ request: R) async throws {
        try await webSocketClient.send(request: request)
    }
    
    func configurePing(pingInterval: TimeInterval, watchdogInterval: TimeInterval) async {
        await webSocketClient.setPing(interval: pingInterval > 0 ? pingInterval : 15)
        await webSocketClient.setWatchdog(interval: watchdogInterval > 0 ? watchdogInterval : 5)
        await webSocketClient.startPingTimer()
    }
    
    func setRouterConfig(to config: CommandRouterConfiguration) async {
        await webSocketClient.setRouterConfig(to: config)
    }
}

extension WebSocketManager {
#if DEBUG
    @_spi(SendbirdInternal) public func setStatManagerForTest(_ statManager: StatManager?) {
        // TODO: SendbirdChatMain.statManager를 교체해야 함.
        //        self.statManager = statManager
    }

    @_spi(SendbirdInternal) public func injectWebSocketClientForTest(_ client: any ChatWebSocketClientInterface) async {
        await changeWebSocketClient(client)
    }
    
    @_spi(SendbirdInternal) public func getWebSocketClient() -> any ChatWebSocketClientInterface {
        webSocketClient
    }
#endif
}
