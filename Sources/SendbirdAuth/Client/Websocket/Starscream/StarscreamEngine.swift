//
//  StarscreamEngine.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation
import Starscream

package class StarscreamEngine: NSObject {
    @InternalAtomic package var state: AuthWebSocketConnectionState
    private(set) var delegateQueue: DispatchQueue
    package weak var delegate: ChatWebSocketDelegate?
    
    @InternalAtomic private var socket: WebSocket?
    
    package required override init() {
        self.state = .closed
        self.delegateQueue = DispatchQueue(label: "com.sendbird.core.networking.websocket.starscream_\(UUID().uuidString)")
    }
}

extension StarscreamEngine: ChatWebSocketEngine {
    package var identifier: String {
        ""
    }
    
    package func registerObservers(identifier: String) {
        
    }
    
    package func createNewWebSocketEngine() -> ChatWebSocketEngine? {
        return nil
    }

    package var currentRequest: URLRequest? { socket?.request }
    
    package func start(with urlRequest: URLRequest) {
        Logger.client.verbose("\(Self.self) started with request: \(urlRequest)")
        socket?.disconnect()

        let webSocket = WebSocket(request: urlRequest)
        webSocket.callbackQueue = self.delegateQueue
        
        state = .connecting
        socket = webSocket
        
        webSocket.delegate = self
        webSocket.connect()
    }
    
    package func stop(statusCode: ChatWebSocketStatusCode) {
        socket?.disconnect(
            forceTimeout: 0,
            closeCode: UInt16(statusCode.rawValue)
        )
    }
    
    package func forceStop() {
        socket?.disconnect()
    }
    
    package func sendData(_ data: Data, completionHandler: ErrorHandler?) {
        socket?.write(data: data, completion: {
            completionHandler?(nil)
        })
    }
    
    package func sendString(_ string: String, completionHandler: ErrorHandler?) {
        socket?.write(string: string, completion: {
            completionHandler?(nil)
        })
    }
}

extension StarscreamEngine: WebSocketDelegate {
    package func websocketDidConnect(socket: WebSocketClient) {
        state = .open
        delegate?.webSocket(openWith: self)
    }
    
    package func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        defer { state = .closed }
        
        guard let error = error as? WSError else {
            delegate?.webSocket(self, closeWith: .abnormal, reason: nil)
            return
        }
        
        delegate?.webSocket(self, failWith: error)
    }
    
    package func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        delegate?.webSocket(self, receive: .string(text))
    }
    
    package func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        delegate?.webSocket(self, receive: .data(data))
    }
}
