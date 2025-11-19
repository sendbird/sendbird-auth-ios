//
//  ZeroGapRequestSender.swift
//  SendbirdChat
//
//  Created by Kai Lee on 3/11/25.
//

import Foundation

/// Zero gap: Dispatches all requests as soon as they are received.
package actor ZeroGapRequestSender: WebSocketRequestSendable {
    package let sendHandler: WebSocketRequestHandler
    
    package init(sendHandler: @escaping WebSocketRequestHandler) {
        self.sendHandler = sendHandler
    }
    
    package func send(_ request: some ResultableWSRequest) async {
        Task { try await sendHandler(request) }
    }
}
