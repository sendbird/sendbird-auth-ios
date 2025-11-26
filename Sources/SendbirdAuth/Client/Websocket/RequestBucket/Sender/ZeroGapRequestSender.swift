//
//  ZeroGapRequestSender.swift
//  SendbirdChat
//
//  Created by Kai Lee on 3/11/25.
//

import Foundation

/// Zero gap: Dispatches all requests as soon as they are received.
@_spi(SendbirdInternal) public actor ZeroGapRequestSender: WebSocketRequestSendable {
    @_spi(SendbirdInternal) public let sendHandler: WebSocketRequestHandler
    
    @_spi(SendbirdInternal) public init(sendHandler: @escaping WebSocketRequestHandler) {
        self.sendHandler = sendHandler
    }
    
    @_spi(SendbirdInternal) public func send(_ request: some ResultableWSRequest) async {
        Task { try await sendHandler(request) }
    }
}
