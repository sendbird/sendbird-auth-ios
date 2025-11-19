//
//  SessionWebSocketEngine.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation
import Network

package class SessionWebSocketEngine: NSObject {
    package struct Constants {
        package static let queueName = "com.sendbird.core.networking.websocket.queue"
    }
    
    @InternalAtomic package var state: AuthWebSocketConnectionState
    package weak var delegate: ChatWebSocketDelegate?
    
    @InternalAtomic private var session: URLSession?
    @InternalAtomic private var websocketTask: URLSessionWebSocketTask?
    @InternalAtomic private var request: URLRequest?
    private let queue: OperationQueue
    private let dispatchQueue: DispatchQueue
    
    @InternalAtomic private var moniter: NWPathMonitor?
    @InternalAtomic private var status: NWPath.Status = .requiresConnection
    
    private var listenTask: Task<Void, Never>?
    
    package required override init() {
        let queue = OperationQueue()
        queue.name = Constants.queueName
        queue.maxConcurrentOperationCount = 1
        self.queue = queue
        
        self.dispatchQueue = DispatchQueue(label: "com.sendbird.core.networking.websocket.monitor_\(UUID().uuidString)")
        self.state = .closed
    }
    
    deinit {
        listenTask?.cancel()
    }
}

extension SessionWebSocketEngine: ChatWebSocketEngine {
    package var identifier: String {
        ""
    }
    
    package func registerObservers(identifier: String) {
        
    }
    
    package func createNewWebSocketEngine() -> ChatWebSocketEngine? {
        return nil
    }

    package var currentRequest: URLRequest? { request }
    
    package func start(with urlRequest: URLRequest) {
        Logger.socket.debug("\(Self.self) started with request: \(urlRequest) --END")
        self.websocketTask?.cancel(with: .normalClosure, reason: nil)
        self.state = .connecting
        
        let config = URLSessionConfiguration.ephemeral
        config.tlsMaximumSupportedProtocolVersion = .TLSv13
        let session = URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: self.queue
        )
        self.session = session
        
        self.request = urlRequest
        self.websocketTask = session.webSocketTask(with: urlRequest)
        self.listen()
        self.websocketTask?.resume()
        
        let moniter = NWPathMonitor()
        moniter.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            
            let oldStatus = self.status
            let newStatus = path.status
            
            if newStatus == .unsatisfied, newStatus != oldStatus {
                self.delegate?.webSocket(self, failWith: AuthClientError.webSocketConnectionFailed.asAuthError)
            }
            
            self.status = newStatus
        }
        
        moniter.start(queue: self.dispatchQueue)
        self.moniter = moniter
    }
    
    package func stop(statusCode: ChatWebSocketStatusCode) {
        Logger.socket.debug("\(Self.self) stop(statusCode: \(statusCode))")
        let code = URLSessionWebSocketTask.CloseCode(rawValue: statusCode.rawValue) ??
        URLSessionWebSocketTask.CloseCode.normalClosure
        state = .closed
        websocketTask?.cancel(with: code, reason: nil)
        moniter?.cancel()
        listenTask?.cancel()
        delegate = nil
    }
    
    package func forceStop() {
        Logger.socket.debug("\(Self.self) forceStop")
        self.state = .closed
        self.moniter?.cancel()
        self.websocketTask?.cancel()
        self.session?.finishTasksAndInvalidate()
        self.listenTask?.cancel()
        self.moniter = nil
        self.websocketTask = nil
        self.session = nil
        self.delegate = nil
    }
    
    package func sendData(_ data: Data, completionHandler: ErrorHandler?) {
        websocketTask?.send(.data(data), completionHandler: { error in
            completionHandler?(error)
        })
    }
    
    package func sendString(_ string: String, completionHandler: ErrorHandler?) {
        websocketTask?.send(.string(string), completionHandler: { error in
            completionHandler?(error)
        })
    }
    
    /// - Warning: Must be called inside `connectQueue
    private func listen() {
        // NOTE: task will be changed.
        guard let websocketTask,
              self.websocketTask === websocketTask,
              websocketTask.state != .completed, websocketTask.state != .canceling,
              self.state != .closed else {
            return
        }
        
        listenTask = Task {
            do {
                let message = try await websocketTask.receive()
                try Task.checkCancellation() // Check if task is cancelled before delegate call
                
                Logger.socket.debug("\(Self.self) received result from listen. task \(String(describing: self.websocketTask))")
                
                switch message {
                case .data(let data):
                    self.delegate?.webSocket(self, receive: .data(data))
                case .string(let string):
                    self.delegate?.webSocket(self, receive: .string(string))
                default:
                    break
                }
                
                self.listen()
            } catch {
                self.delegate?.webSocket(self, failWith: error)
                // TODO: fail error call infinitely in some debug case
                // if code 57 (socket not connected, abort listen)
                return
            }
        }
    }
}

extension SessionWebSocketEngine: URLSessionWebSocketDelegate, URLSessionDataDelegate {
    package func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Logger.main.debug("WebSocket connection opened with protocol: \(String(describing: `protocol`))")
        self.state = .open
        delegate?.webSocket(openWith: self)
    }
    
    package func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        Logger.main.debug("WebSocket connection closed with closeCode: \(closeCode), reason: \(String(describing: reason))")
        self.state = .closed
        var reasonString: String = ""
        if let reason = reason, let str = String(data: reason, encoding: .utf8) {
            reasonString = str
        }
        delegate?.webSocket(
            self,
            closeWith: ChatWebSocketStatusCode(rawValue: closeCode.rawValue) ?? .invalid,
            reason: reasonString
        )
    }
    
    package func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        Logger.main.debug("WebSocket task completed with error: \(String(describing: error))")
        if let error {
            // delegate 호출해서 고객한테 에러 콜백이 가도록 함
            delegate?.webSocket(self, failWith: error)
        }
        
        // [CORE-4085] It might be FLEX library's swizzling bug,
        // but it is difficult to clarify the cause because it is not reproducible in the sample app.
        // Since customers are complaining that they are having difficulties right now,
        // we decided to add an empty implementation for `urlSession(_:task:didCompleteWithError:)`.
    }
}
