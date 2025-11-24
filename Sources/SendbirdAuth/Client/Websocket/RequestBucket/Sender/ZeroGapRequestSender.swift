//
//  ZeroGapRequestSender.swift
//  SendbirdChat
//
//  Created by Kai Lee on 3/11/25.
//

import Foundation

/// Zero gap: Dispatches all requests as soon as they are received.
public actor ZeroGapRequestSender: WebSocketRequestSendable {
    public let sendHandler: WebSocketRequestHandler
    
    public init(sendHandler: @escaping WebSocketRequestHandler) {
        self.sendHandler = sendHandler
    }
    
    public func send(_ request: some ResultableWSRequest) async {
        Task { try await sendHandler(request) }
    }
}
