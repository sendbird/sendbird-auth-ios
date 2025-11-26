//
//  WebSocketEngineEvent.swift
//  SendbirdChat
//
//  Created by Kai Lee on 9/11/25.
//

import Foundation

@_spi(SendbirdInternal) public enum WebSocketEngineEvent {
    case opened
    case closed(closeCode: URLSessionWebSocketTask.CloseCode, reason: String?)
    case received(URLSessionWebSocketTask.Message)
    case connectionFailed(Error)
}
