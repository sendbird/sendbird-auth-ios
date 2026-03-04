//
//  CommandRouter.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/08.
//

import Foundation

protocol CommandRouterInterface {
    var webSocketConnectionState: AuthWebSocketConnectionState { get }
    
    func connect(key: LoginKey, sessionKey: String?, completionHandler: AuthUserHandler?)
    
    func disconnect() async
    func reset() async
    func cancelTask(with requestId: String, completionHandler: BoolHandler?)
    
    func send<R: APIRequestable>(
        request: R,
        sessionKey: String?,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]?,
        progressHandler: MultiProgressHandler?,
        completion: R.CommandHandler?
    )
    func send<R: ResultableWSRequest>(request: R, ackTimeoutHandler: R.CommandHandler?) async throws
    func send<R: WSRequestable>(request: R) async throws
    
    func startPingTimer(pingInterval: TimeInterval, watchdogInterval: TimeInterval, completion: @escaping VoidHandler)
    func setUploadFileSizeLimit(_ limit: Int64)
}

@_spi(SendbirdInternal) public class CommandRouter: CommandRouterInterface, Injectable {
    // MARK: Injectable
    @DependencyWrapper private var dependency: Dependency?
    private var config: SendbirdConfiguration? { dependency?.config }
    private var statManager: StatManager? { dependency?.statManager }
    
    @_spi(SendbirdInternal) public private(set) var routerConfig: CommandRouterConfiguration
    @_spi(SendbirdInternal) public func setRouterConfig(_ config: CommandRouterConfiguration) {
        Task { 
            await webSocketManager.setRouterConfig(to: config) 
            apiClient.routerConfig = config
        }
    }

    @InternalAtomic @_spi(SendbirdInternal) public var webSocketManager: WebSocketManager {
        willSet {
            websocketManagerEventTask?.cancel()
            Task { await webSocketManager.webSocketClient.forceDisconnect() }
        }
        didSet {
            startListeningWebSocketManagerEvents()
        }
    }
    
    @_spi(SendbirdInternal) public var apiClient: HTTPClientInterface
    
    private var ackTimerManager = AckTimerManager()
    
    @_spi(SendbirdInternal) public var eventDispatcher: EventDispatcher
    
    @_spi(SendbirdInternal) public var webSocketConnectionState: AuthWebSocketConnectionState { webSocketManager.connectionState }
    @_spi(SendbirdInternal) public var connected: Bool { webSocketManager.connectionState == .open }
    
    @_spi(SendbirdInternal) public var parsingStrategy: ((String) -> (Command?))?

    private let externalParsingStrategies = SafeDictionary<String, [String: (String) -> Command?]>()
    
    @_spi(SendbirdInternal) public weak var requestHeaderDataSource: RequestHeaderDataSource?
    
    // api send (maxConcurrent: 1)
    private let apiOperationQueue: OperationQueue
    private let apiQueue: DispatchQueue = DispatchQueue(label: "com.sendbird.core.command_router_api_\(UUID().uuidString)")

    private lazy var markAsReadBucket: BatchedRequestBucket? = {
        BatchedRequestBucket(
            commandType: .read,
            strategy: .zeroGap
        ) { [weak self] request in
            guard let self else { return }
            try await self.webSocketManager.sendWS(request)
        }
    }()
    
    @_spi(SendbirdInternal) public init(
        routerConfig: CommandRouterConfiguration,
        webSocketManager: WebSocketManager,
        httpClient: HTTPClientInterface,
        eventDispatcher: EventDispatcher
    ) {
        self.routerConfig = routerConfig
        self.eventDispatcher = eventDispatcher
        
        self.webSocketManager = webSocketManager
        self.apiClient = httpClient

        self.apiOperationQueue = OperationQueue()
        self.apiOperationQueue.maxConcurrentOperationCount = 1
        self.apiOperationQueue.underlyingQueue = self.apiQueue

        _ = self.markAsReadBucket
        startListeningWebSocketManagerEvents()
    }
    
    private func processCommand(_ command: Command) async {
        if let bucket = self.markAsReadBucket, await bucket.shouldFlush(command) {
            await bucket.flushPendingRequests(with: command) { cmd in
                self.handleReceived(command: cmd)
            }
        } else {
            self.handleReceived(command: command)
        }
    }
    
    private var websocketManagerEventTask: Task<Void, Never>?
    private func startListeningWebSocketManagerEvents() {
        websocketManagerEventTask?.cancel()

        websocketManagerEventTask = Task { [weak self] in
            guard let self else { return }

            let stream = await self.webSocketManager.makeStream()
            for await event in stream {
                guard !Task.isCancelled else { break }

                switch event {
                case .didReceiveMessage(let message):
                    self.didReceiveMessage(message)
                }
            }
        }
    }

    deinit {
        websocketManagerEventTask?.cancel()
    }
    
    func addExternalParsingStrategy(
        for cmdType: String,
        identifier: String,
        strategy: @escaping (String) -> Command?
    ) {
        externalParsingStrategies.mutate(forKey: cmdType) { existing in
            var strategies = existing ?? [:]
            strategies[identifier] = strategy
            return strategies
        }
    }

    func removeExternalParsingStrategy(
        for cmdType: String,
        identifier: String
    ) {
        externalParsingStrategies.mutate(forKey: cmdType) { existing in
            var strategies = existing ?? [:]
            strategies.removeValue(forKey: identifier)
            return strategies.isEmpty ? nil : strategies
        }
    }

    private func didReceiveMessage(_ message: String) {
        Logger.socket.debug("[WS Recv] \(message)")

        // External parsing strategies: broadcast to registered handlers first
        let cmdString = String(message.prefix(4))
        if let strategies = externalParsingStrategies[cmdString], !strategies.isEmpty {
            for (_, strategy) in strategies {
                _ = strategy(message)
            }
        }

        // Existing parsingStrategy path (always executed)
        guard let command = self.parsingStrategy?(message) else {
            return
        }

        let isAckFromCurrentDevice = (command as? SBCommand)?.isAckFromCurrentDeviceRequest ?? false

        if isAckFromCurrentDevice {
            // ACK responses should be handled in SocketSendActor context
            Task { @SocketSendActor [weak self] in
                guard let self = self else { return }
                await self.processCommand(command)
            }
        } else {
            // Regular events use SocketReceiveActor
            Task { @SocketReceiveActor [weak self] in
                guard let self else { return }
                await self.processCommand(command)
            }
        }
    }
    
    func connect(key loginKey: LoginKey, sessionKey: String?, completionHandler: AuthUserHandler?) {
        Task { @SocketSendActor in
            self.webSocketManager.connect(loginKey: loginKey, sessionKey: sessionKey, completionHandler: completionHandler)
        }
    }
    
    @SocketSendActor
    func disconnect() async {
        await webSocketManager.webSocketClient.disconnect()
    }
    
    @SocketSendActor
    func reset() async {
        apiOperationQueue.cancelAllOperations()
        
        apiClient.clear()
        await ackTimerManager.clear()
        await disconnect()
    }
    
    @_spi(SendbirdInternal) public func createAPIHeaders<R: APIRequestable>(for request: R) -> [String: String] {
        let paramsBuilder = RequestHeadersBuilder()
        
        paramsBuilder.append(key: "Accept", value: "application/json")
        paramsBuilder.append(key: "Connection", value: "Keep-Alive")
        paramsBuilder.append(key: "Request-Sent-Timestamp", value: String(Date().milliSeconds))

        guard let requestHeaderContext = requestHeaderDataSource?.requestHeaderContext else {
            Logger.socket.info("requestHeaderContext must not be nil")
            return paramsBuilder.buildDictionary()
        }

        paramsBuilder.append(key: "SendBird", value: requestHeaderContext.sendbirdHeader)
        paramsBuilder.append(key: "User-Agent", value: requestHeaderContext.userAgent)
        paramsBuilder.append(key: "SB-User-Agent", value: requestHeaderContext.sbUserAgent)
        paramsBuilder.append(key: "SB-SDK-User-Agent", value: requestHeaderContext.sbSdkUserAgent)

        return paramsBuilder.buildDictionary()
    }
    
    @_spi(SendbirdInternal) public func send<R: APIRequestable>(
        request: R,
        sessionKey: String?,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]? = nil,
        progressHandler: MultiProgressHandler? = nil,
        completion: R.CommandHandler?
    ) {
        var headers = createAPIHeaders(for: request)
        if request.isSessionRequired {
            headers["Session-Key"] = sessionKey
        }
        
        apiOperationQueue.addOperation { [weak self] in
            guard let self = self else { return }
            
            // register WSeventDeduplicationRule (manager type, SBCommand type, unique ID)
            if let rules = wsEventDeduplicationRules {
                self.eventDispatcher.register(deduplicationRules: rules)
            }
            
            // send API request
            if request.hasMultipart {
                self.apiClient.send(
                    multipartRequest: request,
                    headers: headers,
                    progressHandler: progressHandler
                ) { response, error in
                    guard let response = response,
                          error == nil else {
                        completion?(nil, error)
                        return
                    }
                    
                    completion?(response, nil)
                }
            } else {
                self.apiClient.send(request: request, headers: headers) { (response, err) in
                    completion?(response, err)
                }
            }
        }
    }
    
    @SocketSendActor
    func send<R: ResultableWSRequest>(request: R, ackTimeoutHandler: R.CommandHandler? = nil) async throws {
        guard let socketResponseTimeout = self.config?.socketResponseTimeout else {
            Logger.main.error(errorMessage: .notResolved)
            return
        }
        
        Logger.socket.info("About to send request \(String(describing: type(of: request)))")
        
        if request.commandType.isAckRequired {
            await ackTimerManager.register(
                request: request,
                completionHandler: ackTimeoutHandler,
                timeout: socketResponseTimeout
            )
        }
        
        Logger.socket.info("WebSocket client send via manager")
        Logger.client.verbose("Sending WS Request: \(request.commandType.rawValue)(\(String(describing: type(of: request))))")
        
        if let bucket = markAsReadBucket, bucket.shouldHold(request) {
            await bucket.hold(request)
        } else {
            try await webSocketManager.sendWS(request)
        }
    }

    @SocketSendActor
    func send<R: WSRequestable>(request: R) async throws {
        Logger.client.verbose("Sending WS Request: \(request.commandType.rawValue)(\(String(describing: type(of: request))))")
        try await self.webSocketManager.sendWS(request)
    }
    
    func cancelTask(with requestId: String, completionHandler: BoolHandler?) {
        apiOperationQueue.addOperation { [weak self] in
            self?.apiClient.cancelUpload(with: requestId, completionHandler: completionHandler)
        }
    }
    
    // MARK: Injectable
    @_spi(SendbirdInternal) public func resolve(with dependency: (any Dependency)?) {
        self.dependency = dependency
    }
}

// MARK: - WebSocket
extension CommandRouter {
    func startPingTimer(pingInterval: TimeInterval, watchdogInterval: TimeInterval, completion: @escaping VoidHandler) {
        Task { @SocketSendActor in
            await self.webSocketManager.configurePing(
                pingInterval: pingInterval,
                watchdogInterval: watchdogInterval
            )
            completion()
        }
    }
}

// MARK: - API
extension CommandRouter {
    func setUploadFileSizeLimit(_ limit: Int64) {
        apiOperationQueue.addOperation { [weak self] in
            self?.apiClient.uploadSizeLimit = limit
        }
    }
}

extension CommandRouter {
    @_spi(SendbirdInternal) public func handleReceived(command: Command) {
        self.eventDispatcher.dispatch(command: command) { [weak self] in
            guard let self else {
                return
            }
            
            Task {
                if let command = command as? SBCommand,
                   await self.ackTimerManager.contains(command.requestId) || command.isAckFromCurrentDeviceRequest {
                    await self.ackTimerManager.handleResponse(with: command)
                }
                
                if let logiEvent = command as? LoginEvent {
                    self.statManager?.append(logiEvent: logiEvent)
                }
            }
        }
    }
}

#if DEBUG
// MARK: Test Helper
extension CommandRouter {
    @_spi(SendbirdInternal) public func getRequestHeaderContext() -> RequestHeadersContext? {
        return self.requestHeaderDataSource?.requestHeaderContext
    }
    
    @_spi(SendbirdInternal) public func getWebsocketClient() -> any ChatWebSocketClientInterface {
        return self.webSocketManager.webSocketClient
    } 
    
    @_spi(SendbirdInternal) public func getRequestHeaderDict<R: APIRequestable>(request: R) -> [String: String] {
        return self.createAPIHeaders(for: request)
    }

    @_spi(SendbirdInternal) public func simulateDidReceiveMessage(_ message: String) {
        self.didReceiveMessage(message)
    }
}
#endif

@globalActor actor SocketSendActor {
    static let shared = SocketSendActor()
}

@globalActor actor SocketReceiveActor {
    static let shared = SocketReceiveActor()
}
