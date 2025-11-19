//
//  AckTimerManager.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/03.
//

import Foundation

package enum ACKKey: String {
    case requestId   = "request_id"
    case handler     = "handler"
    case command     = "command"
    case type        = "type"
}

package final class AckTimerManager {
    package let board: SBTimerBoard
    
    package init(board: SBTimerBoard = SBTimerBoard()) {
        self.board = board
    }
    
    package func contains(_ requestId: String?) -> Bool {
        guard let requestId = requestId else { return false }
        return board.timer(identifier: requestId) != nil
    }
    
    package func handleResponse(with command: SBCommand, error: Error? = nil) {
        guard let identifier = command.reqId else { return }
        guard let timer = board.timer(identifier: identifier), timer.valid else { return }
        
        Logger.external.info("ACK timer: \(timer)")
        timer.stop()
        
        guard let request = timer.userInfo?[ACKKey.command.rawValue] as? AnyResultable else { return }
        guard let handler = timer.userInfo?[ACKKey.handler.rawValue] else { return }
        
        if let errorCommand = command as? ErrorEvent {
            request.handleError(errorCommand.asAuthError, handler: handler)
        } else {
            request.handleCommand(command, handler: handler)
        }
    }
    
    package func register<R: ResultableRequest>(request: R, completionHandler: R.CommandHandler? = nil, timeout: TimeInterval) {
        guard let identifier = (request as? WSRequestable)?.requestId else { return }
        
        let userInfo: [String: Any?] = [
            ACKKey.command.rawValue: request,
            ACKKey.handler.rawValue: completionHandler
        ]
        
        SBTimer(
            timeInterval: timeout,
            userInfo: userInfo.compactMapValues { $0 },
            onBoard: board,
            identifier: identifier
        ) {
            completionHandler?(nil, AuthClientError.ackTimeout.asAuthError)
        }
    }
    
    package func clear(completion: (() -> Void)? = nil) {
        Logger.external.info("Configure ACK Timers.")
        let timers = board.timers
        
        guard !timers.isEmpty else {
            completion?()
            return
        }
        
        let endIndex = (timers.count - 1)
        
        for (index, timer) in timers.enumerated() {
            timer.stop()
            defer { if endIndex == index { completion?() } }
            
            guard let request = timer.userInfo?[ACKKey.command.rawValue] as? AnyResultable else { return }
            guard let handler = timer.userInfo?[ACKKey.handler.rawValue] else { return }
            
            request.handleError(AuthCoreError.requestFailed.asAuthError, handler: handler)
        }
    }
}
