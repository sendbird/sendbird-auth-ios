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

package class CommandRouter: CommandRouterInterface, WebSocketManagerDelegate, Injectable {
    // MARK: Injectable
    @DependencyWrapper private var dependency: Dependency?
    private var config: SendbirdConfiguration? { dependency?.config }
    private var statManager: StatManager? { dependency?.statManager }
    
    package var routerConfig: CommandRouterConfiguration {
        didSet {
            webSocketManager.webSocketClient.routerConfig = routerConfig
            apiClient.routerConfig = routerConfig
        }
    }

    @InternalAtomic package var webSocketManager: WebSocketManager {
        willSet {
            webSocketManager.webSocketClient.forceDisconnect()
        }
    }
    package var webSocketClient: ChatWebSocketClientInterface {
        get { webSocketManager.webSocketClient }
        set { webSocketManager.webSocketClient = newValue }
    }
    
    package var apiClient: HTTPClientInterface
    
    package var ackTimerManager = AckTimerManager()
    
    package var eventDispatcher: EventDispatcher
    
    package var webSocketConnectionState: AuthWebSocketConnectionState { webSocketManager.connectionState }
    package var connected: Bool { webSocketManager.connectionState == .open }
    
    package var parsingStrategy: ((String) -> (Command?))?
    
    package weak var requestHeaderDataSource: RequestHeaderDataSource?
    
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
            
            return try await withCheckedThrowingContinuation { continuation in
                self.webSocketClient.send(request: request) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }
    }()
    
    package var onMessageReceived: ((Command) -> Void)?
    package func didReceiveMessage(_ message: String) {
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
                Task {
                    await bucket.flushPendingRequests(with: command) {
                        self.handleReceived(command: $0)
                    }
                }
            } else {
                self.handleReceived(command: command)
            }
        }
    }
    
    package init(
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
            self?.webSocketManager.webSocketClient.disconnect()
            completion()
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
    
    package func createAPIHeaders<R: APIRequestable>(for request: R) -> [String: String] {
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
    
    package func send<R: APIRequestable>(
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
            
            let webSocketClient = self.webSocketManager.webSocketClient
            Logger.socket.info("WebSocket client: \(webSocketClient)")
            Logger.client.verbose("Sending WS Request: \(request.commandType.rawValue)(\(String(describing: type(of: request))))")
            
            if let bucket = markAsReadBucket, bucket.shouldHold(request) {
                Task { await bucket.hold(request) }
            } else {
                webSocketClient.send(request: request) { error in
                    if let error = error as? AuthError {
                        completion?(nil, error)
                        return
                    }
                }
            }
        }
    }
    
    func send<R: WSRequestable>(request: R) {
        socketSendOperationQueue.addOperation { [weak self] in
            guard let webSocketClient = self?.webSocketManager.webSocketClient else { return }

            Logger.client.verbose("Sending WS Request: \(request.commandType.rawValue)(\(String(describing: type(of: request))))")
            webSocketClient.send(request: request, completion: nil)
        }
    }
    
    func cancelTask(with requestId: String, completionHandler: BoolHandler?) {
        apiOperationQueue.addOperation { [weak self] in
            self?.apiClient.cancelUpload(with: requestId, completionHandler: completionHandler)
        }
    }
    
    // MARK: Injectable
    package func resolve(with dependency: (any Dependency)?) {
        self.dependency = dependency
    }
}

// MARK: - WebSocket
extension CommandRouter {
    func startPingTimer(pingInterval: TimeInterval, watchdogInterval: TimeInterval, completion: @escaping VoidHandler) {
        socketSendOperationQueue.addOperation { [weak webSocketClient = self.webSocketManager.webSocketClient] in
            guard let webSocketClient = webSocketClient else { return }

            webSocketClient.setPing(interval: pingInterval > 0 ? pingInterval : 15)
            webSocketClient.setWatchdog(interval: watchdogInterval > 0 ? watchdogInterval : 5)
            webSocketClient.startPingTimer()
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
    package func handleReceived(command: Command) {
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

// MARK: Test Helper
extension CommandRouter {
    package func getRequestHeaderContext() -> RequestHeadersContext? {
        return self.requestHeaderDataSource?.requestHeaderContext
    }
    
    package func getRequestHeaderDict<R: APIRequestable>(request: R) -> [String: String] {
        return self.createAPIHeaders(for: request)
    }
}
