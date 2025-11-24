//
//  SessionWebSocketEngine.swift
//  SendbirdChat
//
//  Created by Kai Lee on 9/9/25.
//

import Foundation
import Network

actor SessionWebSocketEngine: NSObject, ChatWebSocketEngine {
    private(set) var state: AuthWebSocketConnectionState = .closed
    private var websocketTask: URLSessionWebSocketTask?
    private var runTask: Task<Void, Never>?
    private var session: URLSession?
    private var isClosing: Bool = false
    
    private let monitor: NWPathMonitor
    private let monitorQueue: DispatchQueue
    
    private let eventBroadcaster: AsyncEventBroadcaster<WebSocketEngineEvent>
    
    override init() {
        self.monitorQueue = DispatchQueue(
            label: "com.sendbird.core.networking.websocket.monitor_\(UUID().uuidString)"
        )
        self.monitor = NWPathMonitor()
        
        eventBroadcaster = AsyncEventBroadcaster<WebSocketEngineEvent>()
    }
    
    deinit {
        monitor.cancel()
        runTask?.cancel()
        session?.invalidateAndCancel()
        websocketTask?.cancel(with: .goingAway, reason: nil)
        eventBroadcaster.finishAsync()
    }
    
    var currentRequest: URLRequest? {
        websocketTask?.currentRequest
    }
    
    func makeStream() async -> AsyncStream<WebSocketEngineEvent> {
        await eventBroadcaster.makeStream()
    }
    
    func start(with urlRequest: URLRequest) {
        Logger.socket.debug("\(Self.self) started with request: \(urlRequest) --END")
        
        state = .connecting
        isClosing = false
        
        let config = URLSessionConfiguration.ephemeral
        config.tlsMaximumSupportedProtocolVersion = .TLSv13

        let session = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
        self.session = session
        websocketTask = session.webSocketTask(with: urlRequest)
        
        startNetworkMonitoring()
        
        runTask?.cancel()
        runTask = Task { [weak self] in
            await self?.run()
        }
    }
    
    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        try await websocketTask?.send(message)
    }
    
    func stop(statusCode: ChatWebSocketStatusCode) async {
        guard state != .closed else {
            Logger.socket.debug("\(Self.self) stop ignored: state is already closed")
            return
        }
        
        Logger.socket.debug("\(Self.self) stop(statusCode: \(statusCode))")
        isClosing = true
        
        let code = URLSessionWebSocketTask.CloseCode(rawValue: statusCode.rawValue) ?? .normalClosure
        websocketTask?.cancel(with: code, reason: nil)
        
        state = .closed
        
        monitor.cancel()
        runTask?.cancel()
        runTask = nil
        websocketTask = nil
    }
    
    func forceStop() async {
        Logger.socket.debug("\(Self.self) forceStop")
        
        await stop(statusCode: .abnormal)
    }
    
    nonisolated func createNewWebSocketEngine() -> SessionWebSocketEngine {
        SessionWebSocketEngine()
    }
    
    // MARK: - Private Methods
    
    private func run() async {
        guard let task = websocketTask else {
            return 
        }

        task.resume()
        state = .open

        do {
            while !Task.isCancelled {
                let message = try await task.receive()
                Logger.socket.debug("\(Self.self) received result from listen. task \(String(describing: self.websocketTask))")
                
                // Ensure this loop is still handling the current task
                guard self.websocketTask === task else { break }
                await eventBroadcaster.yield(.received(message))
            }
        } catch {
            Logger.main.debug("WebSocket task completed with error: \(String(describing: error))")
            state = .closed
        }
    }
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                await self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    private func handlePathUpdate(_ path: NWPath) async {
        if path.status == .unsatisfied {
            let error = AuthClientError.webSocketConnectionFailed.asAuthError
            await eventBroadcaster.yield(.connectionFailed(error))
            state = .closed
            runTask?.cancel()
        }
    }
    
    private func setState(_ newState: AuthWebSocketConnectionState) {
        Logger.socket.debug("Websocket engine's state changed from \(state) to \(newState)")
        state = newState
    }
}

// MARK: - URLSessionWebSocketDelegate
extension SessionWebSocketEngine: URLSessionWebSocketDelegate, URLSessionDataDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Logger.main.debug("WebSocket connection opened with protocol: \(String(describing: `protocol`))")

        Task {
            await setState(.open)
            await eventBroadcaster.yield(.opened)
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Logger.main.debug("WebSocket connection closed with closeCode: \(closeCode), reason: \(String(describing: reason))")
        
        var reasonString: String = ""
        if let reason = reason, let str = String(data: reason, encoding: .utf8) {
            reasonString = str
        }
        
        Task {
            await setState(.closed)
            await eventBroadcaster.yield(.closed(closeCode: closeCode, reason: reasonString))
        }
    }
    
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Logger.main.debug("WebSocket task completed with error: \(String(describing: error))")
        Task {
            await setState(.closed)
            await eventBroadcaster.yield(.connectionFailed(error ?? URLError(.unknown)))
        }
        
        // [CORE-4085] It might be FLEX library's swizzling bug,
        // but it is difficult to clarify the cause because it is not reproducible in the sample app.
        // Since customers are complaining that they are having difficulties right now,
        // we decided to add an empty implementation for `urlSession(_:task:didCompleteWithError:)`.
    }
}

#if TESTCASE
extension SessionWebSocketEngine {
    func getBroadcaster() -> AsyncEventBroadcaster<WebSocketEngineEvent> {
        eventBroadcaster
    }
}
#endif
