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
    
    func disconnect(completion: @escaping VoidHandler)
    func reset(completion: @escaping VoidHandler)
    func cancelTask(with requestId: String, completionHandler: BoolHandler?)
    
    func send<R: APIRequestable>(
        request: R,
        sessionKey: String?,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]?,
        progressHandler: MultiProgressHandler?,
        completion: R.CommandHandler?
    )
    func send<R: ResultableWSRequest>(request: R, completion: R.CommandHandler?)
    func send<R: WSRequestable>(request: R)
    
    func startPingTimer(pingInterval: TimeInterval, watchdogInterval: TimeInterval, completion: @escaping VoidHandler)
    func setUploadFileSizeLimit(_ limit: Int64)
}

public class CommandRouter: CommandRouterInterface, WebSocketManagerDelegate, Injectable {
    // MARK: Injectable
    @DependencyWrapper private var dependency: Dependency?
    private var config: SendbirdConfiguration? { dependency?.config }
    private var statManager: StatManager? { dependency?.statManager }
    
    public private(set) var routerConfig: CommandRouterConfiguration
    public func setRouterConfig(_ config: CommandRouterConfiguration) {
        Task { 
            await webSocketManager.setRouterConfig(to: config) 
            apiClient.routerConfig = config
        }
    }

    @InternalAtomic public var webSocketManager: WebSocketManager {
        willSet {
            Task { await webSocketManager.webSocketClient.forceDisconnect() }
        }
    }
    
    public var apiClient: HTTPClientInterface
    
    public var ackTimerManager = AckTimerManager()
    
    public var eventDispatcher: EventDispatcher
    
    public var webSocketConnectionState: AuthWebSocketConnectionState { webSocketManager.connectionState }
    public var connected: Bool { webSocketManager.connectionState == .open }
    
    public var parsingStrategy: ((String) -> (Command?))?
    
    public weak var requestHeaderDataSource: RequestHeaderDataSource?
    
    // socket event (내꺼 말고) 수신 전용
    private let socketReceiveOperationQueue: OperationQueue
    private let socketReceiveQueue: DispatchQueue = DispatchQueue(label: "com.sendbird.core.command_router_socket_receive_\(UUID().uuidString)")
    
    // socket send || 내꺼 ack 수신 (maxConcurrent: 1)
    private let socketSendOperationQueue: OperationQueue
    private let socketSendQueue: DispatchQueue = DispatchQueue(label: "com.sendbird.core.command_router_socket_send_\(UUID().uuidString)")
    
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
    
    public var onMessageReceived: ((Command) -> Void)?
    public func didReceiveMessage(_ message: String) {
        Logger.socket.debug("[WS Recv] \(message)")
        
        guard let command = self.parsingStrategy?(message) else {
            return
        }
        
        let queue = if ((command as? SBCommand)?.isAckFromCurrentDeviceRequest ?? false) == true {
            socketSendOperationQueue
        } else {
            socketReceiveOperationQueue
        }
        queue.addOperation { [weak self] in
            guard let self = self else {
                return
            }
                     
            if let bucket = markAsReadBucket, bucket.shouldFlush(command) {
                Task { [weak self] in
                    guard let self else { return }
                    
                    await bucket.flushPendingRequests(with: command) { cmd in
                        self.handleReceived(command: cmd)
                    }
                }
            } else {
                self.handleReceived(command: command)
            }
        }
    }
    
    public init(
        routerConfig: CommandRouterConfiguration,
        webSocketManager: WebSocketManager,
        httpClient: HTTPClientInterface,
        eventDispatcher: EventDispatcher
    ) {
        self.routerConfig = routerConfig
        self.eventDispatcher = eventDispatcher
        
        self.webSocketManager = webSocketManager
        self.apiClient = httpClient
        
        self.socketReceiveOperationQueue = OperationQueue()
        self.socketReceiveOperationQueue.maxConcurrentOperationCount = 1
        self.socketReceiveOperationQueue.underlyingQueue = self.socketReceiveQueue
        
        self.socketSendOperationQueue = OperationQueue()
        self.socketSendOperationQueue.maxConcurrentOperationCount = 1
        self.socketSendOperationQueue.underlyingQueue = self.socketSendQueue
        
        self.apiOperationQueue = OperationQueue()
        self.apiOperationQueue.maxConcurrentOperationCount = 1
        self.apiOperationQueue.underlyingQueue = self.apiQueue

        _ = self.markAsReadBucket
    }
    
    func connect(key loginKey: LoginKey, sessionKey: String?, completionHandler: AuthUserHandler?) {
        socketSendOperationQueue.addOperation { [weak self] in
            guard let self = self else { return }
            
            self.webSocketManager.connect(loginKey: loginKey, sessionKey: sessionKey, completionHandler: completionHandler)
        }
    }
    
    func disconnect(completion: @escaping VoidHandler) {
        socketSendOperationQueue.addOperation { [weak self] in
            Task { 
                await self?.webSocketManager.webSocketClient.disconnect() 
                completion()
            }
        }
    }
    
    func reset(completion: @escaping VoidHandler) {
        socketReceiveOperationQueue.cancelAllOperations()
        socketSendOperationQueue.cancelAllOperations()
        apiOperationQueue.cancelAllOperations()

        socketSendOperationQueue.addOperation {
            self.apiClient.clear()
            self.ackTimerManager.clear {
                self.disconnect {
                    completion()
                }
            }
        }
    }
    
    public func createAPIHeaders<R: APIRequestable>(for request: R) -> [String: String] {
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
    
    public func send<R: APIRequestable>(
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
    
    func send<R: ResultableWSRequest>(request: R, completion: R.CommandHandler?) {
        socketSendOperationQueue.addOperation { [weak self] in
            guard let self = self else { return }
            guard let socketResponseTimeout = self.config?.socketResponseTimeout else {
                Logger.main.error(errorMessage: .notResolved)
                return
            }
            
            Logger.socket.info("About to send request \(String(describing: type(of: request)))")
            
            if request.commandType.isAckRequired {
                self.ackTimerManager.register(
                    request: request,
                    completionHandler: completion,
                    timeout: socketResponseTimeout
                )
            }
            
            Logger.socket.info("WebSocket client send via manager")
            Logger.client.verbose("Sending WS Request: \(request.commandType.rawValue)(\(String(describing: type(of: request))))")
            
            if let bucket = markAsReadBucket, bucket.shouldHold(request) {
                Task { await bucket.hold(request) }
            } else {
                Task { [weak self] in
                    guard let self else { return }
                    
                    do {
                        try await self.webSocketManager.sendWS(request)
                    } catch {
                        if let authError = error as? AuthError { completion?(nil, authError) }
                    }
                }
            }
        }
    }
    
    func send<R: WSRequestable>(request: R) {
        socketSendOperationQueue.addOperation { [weak self] in
            guard let self else { return }
            Logger.client.verbose("Sending WS Request: \(request.commandType.rawValue)(\(String(describing: type(of: request))))")
            Task {
                try await self.webSocketManager.sendWS(request)
            }
        }
    }
    
    func cancelTask(with requestId: String, completionHandler: BoolHandler?) {
        apiOperationQueue.addOperation { [weak self] in
            self?.apiClient.cancelUpload(with: requestId, completionHandler: completionHandler)
        }
    }
    
    // MARK: Injectable
    public func resolve(with dependency: (any Dependency)?) {
        self.dependency = dependency
    }
}

// MARK: - WebSocket
extension CommandRouter {
    func startPingTimer(pingInterval: TimeInterval, watchdogInterval: TimeInterval, completion: @escaping VoidHandler) {
        socketSendOperationQueue.addOperation { [weak self] in
            guard let self else { return }
            Task {
                await self.webSocketManager.configurePing(
                    pingInterval: pingInterval,
                    watchdogInterval: watchdogInterval
                )
                completion()
            }
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
    public func handleReceived(command: Command) {
        self.eventDispatcher.dispatch(command: command) {
            if let command = command as? SBCommand,
               self.ackTimerManager.contains(command.requestId) || command.isAckFromCurrentDeviceRequest {
                self.ackTimerManager.handleResponse(with: command)
            }
            
            if let logiEvent = command as? LoginEvent {
                self.statManager?.append(logiEvent: logiEvent)
            }
        }
    }
}

#if TESTCASE
// MARK: Test Helper
extension CommandRouter {
    public func getRequestHeaderContext() -> RequestHeadersContext? {
        return self.requestHeaderDataSource?.requestHeaderContext
    }
    
    public func getWebsocketClient() -> any ChatWebSocketClientInterface {
        return self.webSocketManager.webSocketClient
    } 
    
    public func getRequestHeaderDict<R: APIRequestable>(request: R) -> [String: String] {
        return self.createAPIHeaders(for: request)
    }
}
#endif
