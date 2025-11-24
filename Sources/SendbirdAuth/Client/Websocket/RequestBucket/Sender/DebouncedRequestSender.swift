//
//  DebouncedRequestSender.swift
//  SendbirdChat
//
//  Created by Kai Lee on 3/11/25.
//

import Foundation

/// Debounced: Dispatches the latest request after the debounce delay.
public actor DebouncedRequestSender: WebSocketRequestSendable {
    public let sendHandler: WebSocketRequestHandler
    
    private let debounceDelay: TimeInterval
    private var pendingFireTask: Task<Void, Error>?
    
    private let defaultDebounceDelay = 0.5
    
    public init(debounceDelay: TimeInterval? = nil, sendHandler: @escaping WebSocketRequestHandler) {
        self.sendHandler = sendHandler
        self.debounceDelay = debounceDelay ?? defaultDebounceDelay
    }
    
    public func send(_ request: some ResultableWSRequest) async {
        // Cancel the pending fire task if there is any.
        pendingFireTask?.cancel()
        pendingFireTask = Task { [weak self] in
            guard let self else { return }
            
            // Sleep for debounce delay, but silently exit if the task is cancelled before completion.
            try? await Task.sleep(nanoseconds: UInt64(self.debounceDelay * 1_000_000_000))
            
            guard Task.isCancelled == false else {
                return
            }
            
            try await sendHandler(request)
        }
    }
}
