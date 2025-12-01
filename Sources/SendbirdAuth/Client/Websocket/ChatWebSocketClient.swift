//
//  WebSocketClient.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

actor ChatWebSocketClient: ChatWebSocketClientInterface {
    var state: AuthWebSocketConnectionState {
        get async {
            await engine.state
        }
    }
    
    var currentRequest: URLRequest? {
        get async {
            await engine.currentRequest
        }
    }
    
    var routerConfig: CommandRouterConfiguration
    var sendbirdConfig: SendbirdConfiguration
    
    private let engine: any ChatWebSocketEngine
    
    private let eventBroadcaster: AsyncEventBroadcaster<WebSocketClientEvent>
    
    private var recvBuffer: String
    
    private let timerBoard: SBTimerBoard
    private var watchdogTimer: SBTimer?
    private var pingTimer: SBTimer?
    
    private var lastActiveSeconds: TimeInterval = 0
    private var pingInterval: TimeInterval
    private var watchdogInterval: TimeInterval

    private var listenEngineTask: Task<Void, Never>?
    // private var isOpen: Bool = false
    private let jsonEncoder = JSONEncoder()

    init(
        routerConfig: CommandRouterConfiguration,
        sendbirdConfig: SendbirdConfiguration,
        webSocketEngine: (any ChatWebSocketEngine)? = nil
    ) {
        self.recvBuffer = ""
        
        self.routerConfig = routerConfig
        self.sendbirdConfig = sendbirdConfig
        
        self.pingInterval = Constant.pingSendInterval
        self.watchdogInterval = Constant.watchdogTimeout
        self.timerBoard = SBTimerBoard(capacity: Constant.timerCapacity)
        
        self.eventBroadcaster = AsyncEventBroadcaster<WebSocketClientEvent>()
        self.engine = webSocketEngine ?? SessionWebSocketEngine()
    }

    deinit {
        Logger.socket.debug("\(Self.self) deinitialized")
    }
    
    func makeStream() async -> AsyncStream<WebSocketClientEvent> {
        await eventBroadcaster.makeStream()
    }
    
    func createNewClient() async -> any ChatWebSocketClientInterface {
        ChatWebSocketClient(
            routerConfig: self.routerConfig,
            sendbirdConfig: self.sendbirdConfig,
            webSocketEngine: self.engine.createNewWebSocketEngine()
        )
    }
    
    func setRouterConfig(to config: CommandRouterConfiguration) {
        self.routerConfig = config
    }
    
    func connect(
        with urlString: String,
        accessToken: String? = nil,
        sessionKey: String? = nil
    ) async {
        guard let url = URL(string: urlString) else {
            // invalid url
            return
        }
        
        var request = URLRequest(
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
        
        // If the `Origin` is the wsHost, the server denied the connection.
        // The server issue is resolved, but SDK should set the `Origin` with the empty string.
        request.setValue("", forHTTPHeaderField: "Origin")
        Logger.socket.debug("\(Self.self) started with request: \(request) --END")
        await eventBroadcaster.yield(.started)
        
        await startListeningEvent(from: engine)
        await engine.start(with: request)
    }
    
    func disconnect() async {
        Logger.socket.debug("\(Self.self) stop(statusCode: .normal)")
        await cleanupAndStop()
    }
    
    func forceDisconnect() async {
        Logger.socket.debug("\(Self.self) forceStop")
        await cleanupAndStop(isForced: true)
    }
    
    func send<R: WSRequestable>(request: R) async throws {
        guard let encodedData = try? jsonEncoder.encode(request),
              let message = String(data: encodedData, encoding: .utf8) else {
            Logger.http.info("Failed to send request \(request)")
            throw AuthCoreError.requestFailed.asAuthError
        }
        
        // Prefixed by CMD(4 letter), payload body, and a NEW LINE
        Logger.socket.debug("[WS Send] About to send WS \(request.commandType) - \(request.commandType.rawValue)\(message)")

        let messageString = request.commandType.rawValue + message + "\n"
        try await engine.send(.string(messageString))

        Logger.socket.debug("[WS Send] Completed send WS \(request.commandType) - \(request.commandType.rawValue)\(message)")
    }
    
    func setPing(interval: TimeInterval) {
        pingInterval = interval
    }
    
    func setWatchdog(interval: TimeInterval) {
        watchdogInterval = interval
    }
    
    func startPingTimer() {
        pingTimer?.abort()
        Logger.socket.info("Start Pinger.")
        pingTimer = SBTimer(
            timeInterval: Constant.pingCheckInterval,
            userInfo: nil,
            onBoard: timerBoard,
            identifier: "ping",
            repeats: true,
            expirationHandler: { [weak self] in
                Task { await self?.triggerPingIfDue() }
            })
    }
    
    // MARK: - Private methods

    /// Start listening to engine events if not already started
    private func startListeningEvent(from engine: some ChatWebSocketEngine) async {
        guard await engine.state != .open else {
            #if DEBUG
            assertionFailure("It must be preceded to engine start")
            #endif
            return
        }
        
        let engineStream = await engine.makeStream()
        if listenEngineTask == nil || (listenEngineTask?.isCancelled ?? true) {
            listenEngineTask = Task {
                for await event in engineStream {
                    await handleEngineEvent(event)
                }
            }
        }
    }
    
    private func handleEngineEvent(_ event: WebSocketEngineEvent) async {
        switch event {
        case .opened:
            Logger.socket.debug("WS connection opened")
            lastActiveSeconds = Date().timeIntervalSince1970
            
            await eventBroadcaster.yield(.opened)
            
        case .connectionFailed(let error):
            Logger.socket.debug("WS connection fail with error \(error.localizedDescription)")
            stopPingTimer()
            
            await eventBroadcaster.yield(.connectionFailed(error))
            
        case .closed(let code, let reason):
            Logger.socket.debug("WS connection closed with code \(code), reason: \(reason ?? "")")
            stopPingTimer()
            
            await eventBroadcaster.yield(
                .closed(
                    code: ChatWebSocketStatusCode(rawValue: code.rawValue) ?? .invalid,
                    reason: reason
                )
            )
            
        case .received(let wsMessage):
            lastActiveSeconds = Date().timeIntervalSince1970
            stopWatchdogTimer()
            
            guard let message = wsMessage.unzippedString else {
                return
            }
            
            // Efficient incremental parsing: extract lines ending with '\n'
            recvBuffer.append(contentsOf: message)
            while let newlineIndex = recvBuffer.firstIndex(of: "\n") {
                let line = String(recvBuffer[..<newlineIndex])
                // Trim trailing CR for CRLF
                let trimmed = line.last == "\r" ? String(line.dropLast()) : line
                await eventBroadcaster.yield(.received(message: trimmed))
                let nextStart = recvBuffer.index(after: newlineIndex)
                recvBuffer.removeSubrange(..<nextStart)
            }
        }
    }
     
    private func triggerPingIfDue() async {
        let now = Date.now.seconds

        guard await needsToSendPing(at: now) else { return }
        lastActiveSeconds = now
        
        await eventBroadcaster.yield(.timerExpired(type: .ping))
        startWatchdogTimer()
    }
    
    private func needsToSendPing(at current: TimeInterval) async -> Bool {
        return await engine.state == .open &&
        lastActiveSeconds > 0 &&
        current - lastActiveSeconds >= pingInterval
    }
    
    private func stopPingTimer() {
        Logger.socket.info("Stop Pinger.")
        
        pingTimer?.abort()
        stopWatchdogTimer()
    }
    
    private func startWatchdogTimer() {
        Logger.socket.info("Start Watchdog.")
        
        watchdogTimer?.abort()
        watchdogTimer = SBTimer(
            timeInterval: watchdogInterval,
            userInfo: nil,
            onBoard: timerBoard,
            identifier: "watchdog",
            repeats: false,
            expirationHandler: { [weak self] in
                Task {
                    guard let self else { return }
                    
                    await self.stopPingTimer()
                    await self.engine.stop(statusCode: .noStatusReceived)
                }
            }
        )
    }
    
    private func stopWatchdogTimer() {
        Logger.socket.info("Stop Watchdog.")
        watchdogTimer?.abort()
    }
    
    private func cleanupAndStop(isForced: Bool = false) async {
        stopPingTimer()

        if isForced {
            await engine.forceStop()
        } else {
            await engine.stop(statusCode: .normal)
        }
        
        // To receive all remaining events from engine before stopping the listener,
        // listening task should be cancelled after the engine is stopped.
        await Task.yield() // allow pending engine events to be forwarded
        listenEngineTask?.cancel()
        listenEngineTask = nil
    }
}

// MARK: - Constants
extension ChatWebSocketClient {
    enum Constant {
        static let pingCheckInterval: TimeInterval = 1
        static let pingSendInterval: TimeInterval = 15
        static let watchdogTimeout: TimeInterval = 5
        static let timerCapacity = 2
    }
}

// MARK: - Helper method
fileprivate extension URLSessionWebSocketTask.Message {
    /// If data is gzip compressed, decompress and returns UTF8 string value, otherwise returns UTF8 string of original data.
    ///
    /// [SDK Design - WebSocket payload compression]( https://sendbird.atlassian.net/wiki/spaces/SDK/pages/2002354587/SDK+Design+-+WebSocket+payload+compression )
    var unzippedString: String? {
        guard data.isGzipped else {
            return string
        }
        
        guard let gunzipped = try? data.gunzipped() else {
            let message = "unzip error: \(data)"
            assertionFailure(message)
            Logger.socket.error(message)
            return nil
        }
        
        return gunzipped.utf8String
    }
    
    var string: String? {
        switch self {
        case .string(let string):
            return string
        case .data(let data):
            return data.utf8String
        @unknown default:
            return nil
        }
    }
    
    var data: Data {
        switch self {
        case .string(let string):
            return string.utf8Data
        case .data(let data):
            return data
        @unknown default:
            return Data()
        }
    }
}

#if DEBUG
extension ChatWebSocketClient {
    nonisolated func createNewWebSocketEngine() -> any ChatWebSocketEngine {
        engine.createNewWebSocketEngine()
    }
    
    nonisolated func getEngine() -> any ChatWebSocketEngine {
        engine
    }
    
    nonisolated func getBroadcaster() -> AsyncEventBroadcaster<WebSocketClientEvent> {
        eventBroadcaster
    }
}
#endif
