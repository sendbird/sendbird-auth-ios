//
//  UserConnectionManager.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/25.
//

import Foundation

package typealias ConnectionContext = WebSocketContext

package typealias WebSocketContext = WebSocketDataSource & WebSocketActionable & Injectable

package protocol WebSocketDataSource: AnyObject {
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
    /// - Since: [NEXT_VERSION]
    var loginKey: LoginKey? { get }
    
    func notifyNewConnectionStarted()
    func notifyNewReconnectionStarted()
    func notifyConnectionFailed()
    func notifyReconnectionAttempt()
}

package protocol WebSocketActionable: AnyObject {
    func changeState(to nextState: ConnectionStatable)
    func createWebSocketURL(userId: String) -> String
    
    func connectSocket(url: String, accessToken: String?, sessionKey: String?)
    func disconnectSocket()
}

package protocol WebSocketManagerDelegate: AnyObject {
    func didReceiveMessage(_ message: String)
}

package typealias UserConnectionManager = WebSocketManager
package class WebSocketManager {
    // MARK: Injectable
    @DependencyWrapper private var dependency: Dependency?
    private var service: QueueService? { dependency?.service }
    package var stateData: ConnectionStateData? { dependency?.stateData }
    package var config: SendbirdConfiguration? { dependency?.config }
    private var statManager: StatManager? { dependency?.statManager }
    
    /// Should be non-nil once connect() was explicitly called.
    /// - Since: [NEXT_VERSION]
    package var loginKey: LoginKey? = nil

    @InternalAtomic package var state: ConnectionStatable = InitializedState() {
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
    @InternalAtomic package var previousStates: [ConnectionStatable.Type] = []
    #endif

    package let eventDispatcher: EventDispatcher

    package var routerConfig: CommandRouterConfiguration { webSocketClient.routerConfig }
    
    package func performOnCompletionQueue(_ block: (() -> Void)?) {
        service?.performOnCompletionQueue(block)
    }
    
    package var connectionRetryCount: Int {
        statManager?.connectionRetryCount ?? 0
    }
    package var reconnectionTryCount: Int {
        statManager?.reconnectionTryCount ?? 0
    }
    
    package var hostURL: String {
        get { statManager?.wsOpenedEvent?.hostURL ?? "" }
    }
    
    package weak var delegate: WebSocketManagerDelegate?
    
    package var connectionState: AuthWebSocketConnectionState {
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
    
    package let userId: String
    
    package private(set) var netStatus: Reachability.Connection = .unavailable
    
    package func changeNetworkStatus(to status: Reachability.Connection) {
        netStatus = status
        
        if status == .unavailable {
            networkDisconnected()
        }
    }

    package let queue: SafeSerialQueue

    package init(
        userId: String,
        queue: SafeSerialQueue,
        eventDispatcher: EventDispatcher,
        requestHeaderDataSource: RequestHeaderDataSource?,
        routerConfig: CommandRouterConfiguration,
        sendbirdConfig: SendbirdConfiguration,
        webSocketEngine: ChatWebSocketEngine?
    ) {
        Logger.socket.debug("userId: \(userId)")
        self.userId = userId
        self.queue = queue
        self.eventDispatcher = eventDispatcher
        
        self.requestHeaderDataSource = requestHeaderDataSource
        
        self.webSocketClient = ChatWebSocketClient(
            routerConfig: routerConfig,
            sendbirdConfig: sendbirdConfig,
            webSocketEngine: webSocketEngine
        )
        
        webSocketClient.addDelegate(self, forKey: "WebSocketManager_\(UUID().uuidString)")
    }
    
    @InternalAtomic package var webSocketClient: ChatWebSocketClientInterface {
        willSet {
            #if TESTCASE
            // INFO: InterceptableMocking 객체로 교체하는 케이스는 기존 engine 을 사용하기때문에 disconnect 안함
            if newValue is ChatWebSocketClient {
                webSocketClient.forceDisconnect()
            }
            return
            #else
            webSocketClient.forceDisconnect()
            #endif
        }
    }
    package weak var requestHeaderDataSource: RequestHeaderDataSource?
      
    package func createWebSocketURL(
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
        Logger.main.debug("ws request: \(self.routerConfig.wsHost)/?\(params)")
        
        return self.routerConfig.wsHost + "/?" + params
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
    package func resolve(with dependency: (any Dependency)?) {
        self.dependency = dependency
    }
}

extension WebSocketManager: ChatWebSocketClientDelegate {
    package func webSocketClient(startWith client: any ChatWebSocketClientInterface) {
        Logger.socket.debug("started with \(client)")
        
        eventDispatcher.dispatch(
            command: WebSocketStatEvent.WebSocketStartEvent()
        )
    }
    
    package func webSocketClient(openWith client: ChatWebSocketClientInterface) {
        Logger.socket.debug("opened with \(client)")
        if let sentRequest = client.currentRequest {
            // INFO: ws opened
            eventDispatcher.dispatch(
                command: WebSocketStatEvent.WebSocketOpenedEvent(
                    hostURL: sentRequest.url?.host ?? "",
                    openedTimestampMs: Date().milliSeconds
                )
            )
        }
        
        queue.async {
            self.state.didSocketOpen(context: self)
        }
    }
    
    package func webSocketClient(_ client: ChatWebSocketClientInterface, failWith error: Error?) {
        Logger.socket.debug("\(client) failWith \(String(describing: error))")
        let sbError = AuthClientError.webSocketConnectionFailed.asAuthError(
            message: error?.localizedDescription,
            extraUserInfo: (error as? NSError)?.userInfo
        )
        if let sentRequest = client.currentRequest {
            eventDispatcher.dispatch(
                command: WebSocketStatEvent.WebSocketFailedEvent(
                    hostURL: sentRequest.url?.host ?? "",
                    code: sbError.code,
                    reason: sbError.debugDescription
                )
            )
        }
        queue.async {
            self.state.didSocketFail(context: self, error: sbError)
        }
    }
    
    package func webSocketClient(_ client: ChatWebSocketClientInterface, closeWith code: ChatWebSocketStatusCode, reason: String?) {
        Logger.socket.debug("\(client) closeWith \(code), reason: \(String(describing: reason))")
        if let sentRequest = client.currentRequest {
            // This case usually means watch dog timeout
            if code == .noStatusReceived {
                self.dispatchDisconnectEventIfConnected(
                    errorType: AuthClientError.networkError.asAuthError,
                    reasonType: .pingPongTimeout
                )
            } else {
                self.dispatchDisconnectEventIfConnected(
                    errorType: AuthClientError.webSocketConnectionClosed.asAuthError,
                    reasonType: .otherReason(closeCode: code)
                )
            }
        }

        queue.async {
            self.state.didSocketClose(context: self, code: code)
        }
    }
    
    package func webSocketClient(_ client: ChatWebSocketClientInterface, receive message: String) {
        Logger.socket.debug("\(client) receive \(message)")
        delegate?.didReceiveMessage(message)
    }
    
    package func webSocketClient(_ client: ChatWebSocketClientInterface, timerExpiredFor type: ChatWebSocketClientTimerType) {
        Logger.socket.debug("\(client) timerExpiredFor \(type)")
        
        let request = BaseWSRequest<DefaultResponse>(commandType: .ping, requestId: nil, body: [.id: Date().milliSeconds])
        client.send(request: request, completion: nil)
    }
}

extension WebSocketManager: EventDelegate {
    
    package func didReceiveSBCommandEvent(command: SBCommand) async {
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
    
    package func didReceiveInternalEvent(command: InternalEvent) {
        // do-nothing
    }
}

extension WebSocketManager: ConnectionContext {
    package var configForWebSocket: SendbirdConfiguration? { self.config }
    package var serviceForWebSocket: QueueService? { self.service }
    package var dataSourceForWebSocket: ConnectionStateData? { self.stateData }
    
    package var isConnecting: Bool { state is ConnectingState }
    package var isReconnecting: Bool { state is ReconnectingState }
    package var isConnected: Bool { state is ConnectedState }
    package var isDisconnected: Bool { state is LogoutState || state is InternalDisconnectedState }

    // NOTE: should not be called outside of state machine due to
    // deadlock on sync
    package func changeState(to nextState: ConnectionStatable) {
        Logger.session.verbose("\(state) to \(nextState)")
        state = nextState
    }
    
    package func connect(loginKey: LoginKey, sessionKey: String?, completionHandler: AuthUserHandler?) {
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
    
    package func disconnect(isExplicit: Bool = false, completionHandler: VoidHandler? = nil) {
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
    
    package func disconnectWebSocket(completionHandler: VoidHandler? = nil) {
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
    
    package func enterBackground(completionHandler: VoidHandler? = nil) {
        self.dispatchDisconnectEventIfConnected(
            errorType: AuthClientError.webSocketConnectionClosed.asAuthError,
            reasonType: .background
        )
        
        queue.async {
            self.state.didEnterBackground(context: self)
            completionHandler?()
        }
    }
    
    package func networkDisconnected(completionHandler: VoidHandler? = nil) {
        self.dispatchDisconnectEventIfConnected(
            errorType: AuthClientError.networkError.asAuthError,
            reasonType: .networkDisconnected
        )
    }
    
    @discardableResult
    package func reconnect(sessionKey: String?, reconnectedBy: ReconnectingTrigger?) -> Bool {
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
    
    package func connectSocket(url: String, accessToken: String?, sessionKey: String?) {
        // TODO: Shutdown websocket client silently
        // This will trigger websocket disconnectd event, and may cause changes in the state machine.
        // Is it possible to disconnect the websocket client and discard it immediately?
        // P3
        queue.sync {
            Logger.user.debug("current socket client state: \(self.webSocketClient.state.rawValue)")
            if self.webSocketClient.state != .closed {
                self.webSocketClient.disconnect()
            }
            
            let newClient = self.webSocketClient.createNewClient()
            newClient.delegates = self.webSocketClient.delegates
            
            self.webSocketClient = newClient
            
            self.webSocketClient.connect(
                with: url,
                accessToken: accessToken,
                sessionKey: sessionKey
            )
        }
    }
    
    package func disconnectSocket() {
        queue.sync {
            Logger.socket.debug("currentUser: \(self.userId)")
            self.webSocketClient.disconnect()
        }
    }
    
    package func notifyNewConnectionStarted() {
        statManager?.connectionId = UUID().uuidString
        statManager?.connectionRetryCount = 0
    }
    
    package func notifyNewReconnectionStarted() {
        statManager?.connectionId = UUID().uuidString
        statManager?.reconnectionTryCount = 0
    }
    
    package func notifyConnectionFailed() {
        statManager?.connectionRetryCount += 1
    }
    
    package func notifyReconnectionAttempt() {
        statManager?.reconnectionTryCount += 1
    }
}

extension WebSocketManager {
    #if TESTCASE
    package func setStatManagerForTest(_ statManager: StatManager?) {
        // TODO: SendbirdChatMain.statManager를 교체해야 함.
//        self.statManager = statManager
    }
    #endif
}
