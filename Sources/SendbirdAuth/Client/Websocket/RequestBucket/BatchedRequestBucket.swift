//
//  BatchedRequestBucket.swift
//  SendbirdChat
//
//  Created by Kai Lee on 3/4/25.
//

import Foundation

/// An actor class responsible for managing and batching WebSocket requests of a specific command type.
/// The `BatchedRequestBucket` ensures that requests are held, processed, and flushed in a controlled manner
/// based on the provided strategy (e.g., immediate or debounced processing).
///
/// This class is designed to handle requests in a thread-safe manner using Swift's concurrency model.
///
/// - Note: The actor uses a `Strategy` to determine how requests are processed and includes support for
///         testing with a custom dispatcher.
///
/// ## Key Features:
/// - Holds WebSocket requests of a specific command type.
/// - Processes requests in a FIFO order.
/// - Supports zero-gap and debounced request handling strategies.
/// - Ensures thread safety with Swift's actor model.
///
/// ## Usage:
/// 1. Initialize the `BatchedRequestBucket` with a command type, strategy, and dispatch handler.
/// 2. Use `hold(_:)` to queue requests.
/// 3. Use `flush(_:_:async)` to process and dispatch queued requests.
///
/// - Parameters:
///   - commandType: The type of command this bucket is responsible for.
///   - strategy: The strategy for processing requests (e.g., zero-gap or debounced).
///   - sendHandler: A closure to handle the dispatching of WebSocket requests.
@_spi(SendbirdInternal) public actor BatchedRequestBucket {
    @_spi(SendbirdInternal) public let commandType: CommandType
    @_spi(SendbirdInternal) public var pendingRequestsCount: Int {
        requestIdStack.count
    }
    @_spi(SendbirdInternal) public var isFlushInProgress: Bool {
        flushingTask != nil
    }
    
    private let sender: any WebSocketRequestSendable
    
    private var requestIdStack: [String] = []
    private var flushingTask: Task<Void, Never>?
    
    @_spi(SendbirdInternal) public init(
        commandType: CommandType,
        strategy: Strategy,
        sendHandler: @escaping WebSocketRequestHandler
    ) {
        self.commandType = commandType
        self.sender = switch strategy {
        case .zeroGap:
            ZeroGapRequestSender(sendHandler: sendHandler)
        case .debounced(let interval):
            DebouncedRequestSender(debounceDelay: interval, sendHandler: sendHandler)
        }
    }
    
    #if DEBUG
    @_spi(SendbirdInternal) public init(commandType: CommandType, dispatcher: some WebSocketRequestSendable) {
        self.commandType = commandType
        self.sender = dispatcher
    }
    #endif
    
    @_spi(SendbirdInternal) public nonisolated func shouldHold(_ request: some WSRequestable) -> Bool {
        request.commandType == self.commandType
    }
    
    @_spi(SendbirdInternal) public func shouldFlush(_ command: some Command) -> Bool {
        guard
            let command = command as? Bucketable,
            let reqId = command.reqId
        else {
            return false
        }
        
        guard
            command.isAckFromCurrentDeviceRequest,
            requestIdStack.contains(reqId) == true
        else {
            return false
        }
        
        return command.cmd == self.commandType
    }
    
    @_spi(SendbirdInternal) public func hold(_ request: some ResultableWSRequest) async {
        guard
            shouldHold(request),
            let requestId = request.requestId else {
            return
        }
        
        await waitForFlush()

        requestIdStack.append(requestId)
        await fire(request)
    }
    
    /// Flush will be ran in a FIFO order, in separated thread(`Task`)
    @_spi(SendbirdInternal) public func flushPendingRequests(with command: some Command, _ flushHandler: @escaping (Command) async -> Void) async {
        await waitForFlush()
        
        guard let command = command as? Bucketable, shouldFlush(command) else {
            return
        }
        
        flushingTask = Task { [weak self] in
            guard let self, Task.isCancelled == false else { return }
            
            // Flush the received command to the request
            for requestId in await self.requestIdStack {
                guard let commandWithNewId = command.copy(newId: requestId) else {
                    return
                }
                
                await flushHandler(commandWithNewId)
            }
            
            await self.clearStack()
        }
    }
    
    // MARK: - Private
    private func fire(_ request: some ResultableWSRequest) async {
        await sender.send(request)
    }
    
    /// If a flush is in progress, wait until it's done
    private func waitForFlush() async {
        if let flushingTask {
            await flushingTask.value
        }
    }
    
    private func clearStack() {
        requestIdStack.removeAll()
        flushingTask?.cancel()
        flushingTask = nil
    }
}

// MARK: - Strategy
// Add more strategies if needed
extension BatchedRequestBucket {
    /// WebSocket 요청 처리 전략입니다.
    @_spi(SendbirdInternal) public enum Strategy {
        /// 요청을 즉시 처리합니다
        case zeroGap
        /// 요청을 일정 시간 간격(debounce)을 기다린 후 처리합니다
        case debounced(interval: TimeInterval)
    }
}
