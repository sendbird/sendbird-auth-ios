//
//  WebSocketRequestSendable.swift
//  SendbirdChat
//
//  Created by Kai Lee on 3/11/25.
//

import Foundation

public typealias WebSocketRequestHandler = @Sendable (any ResultableWSRequest) async throws -> Void
// ResultableWSRequest -> such as `BaseWSRequest`

/// A protocol that defines the ability to send WebSocket requests.
/// 
/// Types conforming to this protocol must provide a `sendHandler` to manage
/// WebSocket request handling and implement the `send(_:)` method to send
/// requests asynchronously.
/// 
/// - Note: This protocol is intended for use with WebSocket-based communication.
public protocol WebSocketRequestSendable: AnyObject {
    var sendHandler: WebSocketRequestHandler { get }
    func send(_ request: some ResultableWSRequest) async
}
