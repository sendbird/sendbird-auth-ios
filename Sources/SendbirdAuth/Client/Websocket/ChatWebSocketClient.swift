//
//  WebSocketClient.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

package protocol ChatWebSocketClientInterface: AnyObject {
    var routerConfig: CommandRouterConfiguration { get set }
    var sendbirdConfig: SendbirdConfiguration { get set }
    var state: AuthWebSocketConnectionState { get }
    var delegates: NSMapTable<NSString, AnyObject> { get set }
    
    var currentRequest: URLRequest? { get }
    init(routerConfig: CommandRouterConfiguration, sendbirdConfig: SendbirdConfiguration, webSocketEngine: ChatWebSocketEngine?)
    func addDelegate(_ delegate: ChatWebSocketClientDelegate, forKey key: String)
    func disconnect()
    func forceDisconnect()
    func connect(
        with urlString: String,
        accessToken: String?,
        sessionKey: String?
    )
    func send<R: WSRequestable>(request: R, completion: ErrorHandler?) // The default value of the completion should be nil.
    func setPing(interval: TimeInterval)
    func setWatchdog(interval: TimeInterval)
    func startPingTimer()
    func changeWebSocketState(to state: AuthWebSocketConnectionState)
    func createNewClient() -> ChatWebSocketClientInterface
}

package class ChatWebSocketClient: ChatWebSocketClientInterface {
    package enum Constant {
        package static let pingCheckInterval: TimeInterval = 1
        package static let pingSendInterval: TimeInterval = 15
        package static let watchdogTimeout: TimeInterval = 5
        package static let timerCapacity = 2
    }
    
    @InternalAtomic package var routerConfig: CommandRouterConfiguration
    @InternalAtomic package var sendbirdConfig: SendbirdConfiguration
    package var currentRequest: URLRequest? { engine?.currentRequest }
    
    @InternalAtomic private var engine: ChatWebSocketEngine?
    private var recvBuffer: NSMutableString
    
    private let timerBoard: SBTimerBoard
    @InternalAtomic private var watchdogTimer: SBTimer?
    @InternalAtomic private var pingTimer: SBTimer?
    
    private var lastActiveSeconds: TimeInterval = 0
    private var pingInterval: TimeInterval
    private var watchdogInterval: TimeInterval
    
    @InternalAtomic package var delegates: NSMapTable<NSString, AnyObject>
    
    private let queue: SafeSerialQueue
    
    package required init(routerConfig: CommandRouterConfiguration, sendbirdConfig: SendbirdConfiguration, webSocketEngine: ChatWebSocketEngine? = nil) {
        self.queue = SafeSerialQueue(label: "com.sendbird.core.chat_websocket_client.\(UUID().uuidString)")
        self.recvBuffer = NSMutableString()
        
        self.routerConfig = routerConfig
        self.sendbirdConfig = sendbirdConfig
        
        self.pingInterval = Constant.pingSendInterval
        self.watchdogInterval = Constant.watchdogTimeout
        self.timerBoard = SBTimerBoard(capacity: Constant.timerCapacity)
        self.delegates = NSMapTable(keyOptions: .strongMemory, valueOptions: .weakMemory)
        
        if let engine = webSocketEngine {
            self.engine = engine
        } else {
            // The engine will always be listening to the socket because it starts listening since it is created.
            // To prevent dangling listening tasks, it is necessary to stop first.
            engine?.stop(statusCode: .normal)
            
            if #available(iOS 14, *) {
                if let useNative = routerConfig.useNativeSocket, useNative == false {
                    self.engine = StarscreamEngine()
                } else {
                    self.engine = SessionWebSocketEngine()
                }
            } else {
                self.engine = StarscreamEngine()
            }
        }
        self.engine?.delegate = self
    }
    
    deinit {
        Logger.socket.debug("")
    }
    
    package func createNewClient() -> ChatWebSocketClientInterface {
        ChatWebSocketClient(
            routerConfig: self.routerConfig,
            sendbirdConfig: self.sendbirdConfig,
            webSocketEngine: self.engine?.createNewWebSocketEngine()
        )
    }
    
    package func addDelegate(_ delegate: ChatWebSocketClientDelegate, forKey key: String) {
        delegates.setObject(delegate, forKey: key as NSString)
    }
    
    package func dispatch(completionHandler: ((ChatWebSocketClientDelegate) -> Void)) {
        delegates
            .objectEnumerator()?
            .compactMap { $0 as? ChatWebSocketClientDelegate }
            .forEach { completionHandler($0) }
    }
}

extension ChatWebSocketClient: ChatWebSocketDelegate {
    package func webSocket(openWith engine: ChatWebSocketEngine) {
        Logger.socket.debug("WS connection opened")

        dispatch { $0.webSocketClient(openWith: self) }
    }
    
    package func webSocket(_ engine: ChatWebSocketEngine, failWith error: Error?) {
        Logger.socket.debug("WS connection fail with error \(error?.localizedDescription ?? "")")
        
        stopPingTimer()
        
        dispatch { $0.webSocketClient(self, failWith: error) }
    }
    
    package func webSocket(_ engine: ChatWebSocketEngine, closeWith code: ChatWebSocketStatusCode, reason: String?) {
        Logger.socket.debug("WS connection closed with code \(code), reason: \(reason ?? "")")
        
        stopPingTimer()

        dispatch { $0.webSocketClient(self, closeWith: code, reason: reason) }
    }
    
    package func webSocket(_ engine: ChatWebSocketEngine, receive data: ChatWebSocketData) {
        lastActiveSeconds = NSDate().timeIntervalSince1970
        stopWatchdogTimer()
        
        guard let message = data.unzippedString else {
            return
        }
        
        recvBuffer.append(message)
        let msgCount = message.occurencCount(of: "\n")
        let messages = recvBuffer.components(separatedBy: "\n")
        
        for index in 0..<messages.count {
            if index < msgCount {
                dispatch { $0.webSocketClient(self, receive: messages[index]) }
            } else {
                recvBuffer.setString(messages[index])
            }
        }
    }
}

extension ChatWebSocketClient {
    package func setPing(interval: TimeInterval) {
        pingInterval = interval
    }
    
    package func setWatchdog(interval: TimeInterval) {
        watchdogInterval = interval
    }
    
    package func startPingTimer() {
        pingTimer?.abort()
        Logger.socket.info("Start Pinger.")
        pingTimer = SBTimer(
            timeInterval: Constant.pingCheckInterval,
            userInfo: nil,
            onBoard: timerBoard,
            identifier: "ping",
            repeats: true,
            expirationHandler: { [weak self] in
                self?.sendPingIfNeeded()
            })
    }
    
    private func sendPingIfNeeded() {
        let now = Date.now.seconds
        
        guard needsToSendPing(at: now) else { return }
        lastActiveSeconds = now
        dispatch { $0.webSocketClient(self, timerExpiredFor: .ping) }
        startWatchdogTimer()
    }
    
    private func needsToSendPing(at current: TimeInterval) -> Bool {
        return engine?.state == .open &&
        lastActiveSeconds > 0 &&
        current - lastActiveSeconds >= pingInterval
    }
    
    package func stopPingTimer() {
        Logger.socket.info("Stop Pinger.")
        pingTimer?.abort()
        stopWatchdogTimer()
    }
    
    package func startWatchdogTimer() {
        Logger.socket.info("Start Watchdog.")
        watchdogTimer?.abort()
        watchdogTimer = SBTimer(
            timeInterval: watchdogInterval,
            userInfo: nil,
            onBoard: timerBoard,
            identifier: "watchdog",
            repeats: false,
            expirationHandler: { [weak self] in
                guard let self = self else { return }
                self.dispatch { $0.webSocketClient(self, timerExpiredFor: .watchdog) }
                
                self.stopPingTimer()
                self.engine?.stop(statusCode: .noStatusReceived)
                self.dispatch { $0.webSocketClient(self, closeWith: .noStatusReceived, reason: "Watchdog timeout") }
            }
        )
    }
    
    package func stopWatchdogTimer() {
        Logger.socket.info("Stop Watchdog.")
        watchdogTimer?.abort()
    }
}

extension ChatWebSocketClient {
    package func connect(
        with urlString: String,
        accessToken: String? = nil,
        sessionKey: String? = nil
    ) {
        queue.sync {
            guard let url = URL(string: urlString) else {
                // invalid url
                return
            }
            
            let request = NSMutableURLRequest(
                url: url,
                cachePolicy: routerConfig.cachePolicy,
                timeoutInterval: sendbirdConfig.websocketTimeout
            )
            
            let reqTimeStr = "\(Date().milliSeconds)"
            request.setValue(reqTimeStr, forHTTPHeaderField: "Request-Sent-Timestamp")
            if let accessToken = accessToken {
                request.setValue(accessToken, forHTTPHeaderField: "SENDBIRD-WS-TOKEN")
            }
            if let sessionKey = sessionKey {
                request.setValue(sessionKey, forHTTPHeaderField: "SENDBIRD-WS-AUTH")
            }
            
            // Starscream sets the `Origin` with the `url` if the `Origin` is not set.
            // If the `Origin` is the wsHost, the server denied the connection.
            // The server issue is resolved, but SDK should set the `Origin` with the empty string.
            request.setValue("", forHTTPHeaderField: "Origin")
            dispatch { $0.webSocketClient(startWith: self) }
            
            engine?.start(with: request as URLRequest)
        }
    }
    
    package func disconnect() {
        queue.sync {
            Logger.socket.info("Socket disconnect")
            // NOTE: legacy quit with connectionFail error
            stopPingTimer()
            engine?.stop(statusCode: .normal)
        }
    }
    
    package func forceDisconnect() {
        queue.sync {
            Logger.socket.debug("forceDisconnect")
            stopPingTimer()
            engine?.forceStop()
            // NOTE: is this necessary?
            engine = nil
        }
    }
    
    package func send<R: WSRequestable>(request: R, completion: ErrorHandler? = nil) {
        guard let encodedData = try? JSONEncoder().encode(request),
              let message = String(data: encodedData, encoding: .utf8) else {
            Logger.http.info("Failed to send request \(request)")
            completion?(AuthCoreError.requestFailed.asAuthError)
            return
        }
        // Prefixed by CMD(4 letter), payload body, and a NEW LINE
        Logger.socket.debug("[WS Send] About to send WS \(request.commandType) - \(request.commandType.rawValue)\(message)")
        send(string: request.commandType.rawValue + message + "\n") { error in
            Logger.socket.debug("[WS Send] Completed send WS \(request.commandType) - \(request.commandType.rawValue)\(message) with error: \(String(describing: error))")
            completion?(error)
        }
    }
    
    package func send(string: String, completion: ErrorHandler?) {
        queue.sync {
            engine?.sendString(string, completionHandler: completion)
        }
    }
    
    package var state: AuthWebSocketConnectionState { engine?.state ?? .closed }
}

#if !RELEASE
extension ChatWebSocketClient {
    package func changeWebSocketState(to state: AuthWebSocketConnectionState) {
        if let engine = engine as? SessionWebSocketEngine {
            engine.changeWebSocketState(to: state)
        } else if let engine = engine as? StarscreamEngine {
            engine.changeWebSocketState(to: state)
        }
    }
}

extension SessionWebSocketEngine {
    package func changeWebSocketState(to state: AuthWebSocketConnectionState) {
        self.state = state
    }
}

extension StarscreamEngine {
    package func changeWebSocketState(to state: AuthWebSocketConnectionState) {
        self.state = state
    }
}
#endif

#if TESTCASE
extension ChatWebSocketClient {
    package func getEngine() -> ChatWebSocketEngine? {
        engine
    }
}
#endif
