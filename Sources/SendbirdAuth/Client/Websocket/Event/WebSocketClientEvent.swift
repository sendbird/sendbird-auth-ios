//
//  WebSocketClientEvent.swift
//  SendbirdChat
//
//  Created by Kai Lee on 9/11/25.
//

import Foundation

public enum WebSocketClientEvent {
    case started
    case opened
    case connectionFailed(Error)
    case received(message: String)
    case timerExpired(type: ChatWebSocketClientTimerType)
    case closed(code: ChatWebSocketStatusCode, reason: String?)
}
