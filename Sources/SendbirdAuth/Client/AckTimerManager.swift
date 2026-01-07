//
//  AckTimerManager.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/03.
//

import Foundation

actor AckTimerManager {
    private struct AckContext {
        let timer: AsyncTimer
        let request: AnyResultable
        let handler: Any?
    }
    
    private var contexts: [String: [AckContext]] = [:]
     
     init() {}
     
     var isEmpty: Bool {
         contexts.isEmpty
     }

     func contains(_ requestId: String?) -> Bool {
         guard let requestId, let contexts = contexts[requestId] else {
             return false
         }
         
         return !contexts.isEmpty
     }
    
    func handleResponse(with command: SBCommand) async {
        guard let identifier = command.reqId else { return }
        guard let context = popContext(for: identifier) else { return }

        Logger.external.info("ACK timer: identifier=\(identifier) received. Stopping timer.")

        await context.timer.abort()

        if let errorCommand = command as? ErrorEvent {
            context.request.handleError(errorCommand.asAuthError, handler: context.handler)
        } else {
            context.request.handleCommand(command, handler: context.handler)
        }
    }
    
    func register<R: ResultableRequest>(
        request: R,
        completionHandler: R.CommandHandler? = nil,
        timeout: TimeInterval
    ) where R: WSRequestable {
        guard let identifier = request.requestId else { return }

        let timer = AsyncTimer(
            timeInterval: timeout,
            identifier: identifier
        )
        
        storeContext(
            AckContext(
                timer: timer,
                request: request,
                handler: completionHandler
            ),
            for: identifier
        )
        
        timer.run { [weak self] in
            guard let self else { return }
            await self.handleTimeout(for: identifier)
        }
    }
    
    func clear() async {
        Logger.external.info("Configure ACK Timers.")

        let contextsToClear = contexts.values.flatMap { $0 }
        guard !contextsToClear.isEmpty else {
            return
        }

        for context in contextsToClear {
            await context.timer.abort()
            context.request.handleError(
                AuthCoreError.requestFailed.asAuthError,
                handler: context.handler
            )
        }
        
        contexts.removeAll()
    }
    
    // MARK: - Private
    private func storeContext(_ context: AckContext, for identifier: String) {
        var bucket = contexts[identifier] ?? []
        bucket.append(context)
        contexts[identifier] = bucket
    }
    
    private func popContext(for identifier: String) -> AckContext? {
        guard var bucket = contexts[identifier], !bucket.isEmpty else {
            return nil
        }

        let context = bucket.removeFirst()
        contexts[identifier] = bucket.isEmpty ? nil : bucket
        return context
    }
    
    private func handleTimeout(for identifier: String) async {
        guard let context = popContext(for: identifier) else {
            return
        }
        
        Logger.external.warning("ACK Timeout for requestId: \(identifier)")
        
        await context.timer.abort()
        context.request.handleError(AuthClientError.ackTimeout.asAuthError, handler: context.handler)
    }
}
