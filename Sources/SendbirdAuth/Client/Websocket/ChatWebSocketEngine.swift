//
//  ChatWebSocketEngine.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

/// https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent/code
package enum ChatWebSocketStatusCode: Int {
    case invalid = 0
    case normal = 1000
    case goingAway = 1001
    case protocolError = 1002
    case unhandledType = 1003
    // 1004 reserve
    case noStatusReceived = 1005
    case abnormal = 1006
    case invalidUTF8 = 1007
    case policyViolated = 1008
    case messageTooBig = 1009
    case missingExtension = 1010
    case internalError = 1011
    case serviceRestart = 1012
    case tryAgainLater = 1013
    // 1014 reserve
    case TLSHandshake = 1015
    
    var stringValue: String {
        switch self {
        case .invalid: return "Invalid"
        case .normal: return "Normal"
        case .goingAway: return "Going Away"
        case .protocolError: return "Protocol Error"
        case .unhandledType: return "Unhandled Type"
        case .noStatusReceived: return "No Status Received"
        case .abnormal: return "Abnormal"
        case .invalidUTF8: return "Invalid UTF8"
        case .policyViolated: return "Policy Violated"
        case .messageTooBig: return "Message Too Big"
        case .missingExtension: return "Missing Extension"
        case .internalError: return "Internal Error"
        case .serviceRestart: return "Service Restart"
        case .tryAgainLater: return "Try Again Later"
        case .TLSHandshake: return "TLS Handshake"
        }
    }
}

package enum ChatWebSocketClientTimerType {
    case ping
    case watchdog
}

package protocol ChatWebSocketClientDelegate: AnyObject {
    func webSocketClient(startWith client: ChatWebSocketClientInterface)
    func webSocketClient(openWith client: ChatWebSocketClientInterface)
    func webSocketClient(_ client: ChatWebSocketClientInterface, failWith error: Error?)
    func webSocketClient(_ client: ChatWebSocketClientInterface, closeWith code: ChatWebSocketStatusCode, reason: String?)
    func webSocketClient(_ client: ChatWebSocketClientInterface, receive message: String)
    func webSocketClient(_ client: ChatWebSocketClientInterface, timerExpiredFor type: ChatWebSocketClientTimerType)
}

package protocol ChatWebSocketDelegate: AnyObject {
    func webSocket(openWith engine: ChatWebSocketEngine)
    func webSocket(_ engine: ChatWebSocketEngine, failWith error: Error?)
    func webSocket(_ engine: ChatWebSocketEngine, closeWith code: ChatWebSocketStatusCode, reason: String?)
    func webSocket(_ engine: ChatWebSocketEngine, receive data: ChatWebSocketData)
}

package protocol ChatWebSocketEngine: AnyObject {
    init()
    
    var state: AuthWebSocketConnectionState { get }
    var delegate: ChatWebSocketDelegate? { get set }
    var currentRequest: URLRequest? { get }
    var identifier: String { get }
    
    func start(with urlRequest: URLRequest)
    func stop(statusCode: ChatWebSocketStatusCode)
    func forceStop()

    func sendData(_ data: Data, completionHandler: ErrorHandler?)
    func sendString(_ string: String, completionHandler: ErrorHandler?)
    
    func createNewWebSocketEngine() -> ChatWebSocketEngine?
    func registerObservers(identifier: String)
}

package enum ChatWebSocketData {
    case string(String)
    case data(Data)
}

extension ChatWebSocketData {
    
    /// If data is gzip compressed, decompress and returns UTF8 string value, otherwise returns UTF8 string of original data.
    ///
    /// [SDK Design - WebSocket payload compression]( https://sendbird.atlassian.net/wiki/spaces/SDK/pages/2002354587/SDK+Design+-+WebSocket+payload+compression )
    package var unzippedString: String? {
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
    
    private var string: String? {
        switch self {
        case .string(let string):
            return string
        case .data(let data):
            return data.utf8String
        }
    }
    
    private var data: Data {
        switch self {
        case .string(let string):
            return string.utf8Data
        case .data(let data):
            return data
        }
    }
}
