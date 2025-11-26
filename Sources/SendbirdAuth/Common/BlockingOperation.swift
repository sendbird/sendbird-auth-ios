//
//  BlockingOperation.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/09/16.
//

import Foundation

/**
 Operation object that is used to sequentialize asynchronous tasks in a blocking manner.
 No two tasks are run at the same time, and the order of tasks inserted to a `OperationQueue` is guaranteed.
 */
@_spi(SendbirdInternal) public class BlockingOperation: Operation {
    @_spi(SendbirdInternal) public let identifier: String
    
    @_spi(SendbirdInternal) public enum State: String {
        case waiting = "Waiting"
        case ready = "Ready"
        case executing = "Executing"
        case finished = "Finished"
        
        fileprivate var keyPath: String { "is" + rawValue }
    }
    
    @_spi(SendbirdInternal) public var state: State {
        get {
            stateQueue.sync {
                return internalState
            }
        }
        set {
            guard state != newValue else {
                return
            }

            let oldValue = state
            
            willChangeValue(forKey: state.keyPath)
            willChangeValue(forKey: newValue.keyPath)
            
            stateQueue.sync(flags: .barrier) {
                internalState = newValue
            }
            
            didChangeValue(forKey: state.keyPath)
            didChangeValue(forKey: oldValue.keyPath)
        }
    }
    
    private let stateQueue = DispatchQueue(label: "com.sendbird.chat.operation.state.\(UUID().uuidString)", attributes: .concurrent)
    private var internalState: State
    
    private var task: ((BlockingOperation) -> Void)?
    private var synchronous: Bool
    
    @_spi(SendbirdInternal) public var userInfo: [String: Any]
    @_spi(SendbirdInternal) public var didAttemptRun = false
    
    /**
     Initializes `BlockingOperation`.
     - Parameters:
        - taskBlock: closure to be run
        - synchronous: indicates whether the closure includes synchronous work or not. If synchronous is `false`, you must explicitly call `complete()` when finishing the task inside the taskBlock.
        - requireExplicity: indicates whether the closure should wait for explicit call of `markReady()`. If this flag is disabled, the taskBlock runs as soon as the queue is cleared, and the said taskBlock is ready to run. If the flag is enabled, the taskBlock does not run when the queue is cleared, but also waits for the explicit call of `markReady()`, in order to guarantee running certain tasks before running the said task.
     */
    @_spi(SendbirdInternal) public init(taskBlock: @escaping ((BlockingOperation) -> Void), synchronous: Bool, requireExplicity: Bool) {
        self.task = taskBlock
        self.synchronous = synchronous
        self.identifier = UUID().uuidString
        self.userInfo = [:]
        self.internalState = requireExplicity ? .waiting : .ready
    }
    
    @_spi(SendbirdInternal) public convenience init(
        syncTask: @escaping ((BlockingOperation) -> Void),
        requireExplicity: Bool = false
    ) {
        self.init(
            taskBlock: syncTask,
            synchronous: true,
            requireExplicity: requireExplicity
        )
    }
    
    @_spi(SendbirdInternal) public convenience init(
        asyncTask: @escaping ((BlockingOperation) -> Void),
        requireExplicity: Bool = false
    ) {
        self.init(
            taskBlock: asyncTask,
            synchronous: false,
            requireExplicity: requireExplicity
        )
    }
    
    // MARK: Operation
    @_spi(SendbirdInternal) public override var isAsynchronous: Bool { !synchronous }
    
    @_spi(SendbirdInternal) public override var isExecuting: Bool { state == .executing }
    
    @_spi(SendbirdInternal) public override var isFinished: Bool { state == .finished }
    
    /**
     Mark the task as ready when `requireExplicity` was set `true`.
     
     If this task was already ready to be run by the parent `OperationQueue` but did not run because it was not mark as ready, calling this method will run the task immediately.
     */
    @_spi(SendbirdInternal) public func markReady() {
        state = .ready
        if didAttemptRun {
            execute()
        }
    }
    
    @_spi(SendbirdInternal) public override func main() {
        if isCancelled {
            provisionalComplete()
            return
        }
        
        if state == .ready {
            execute()
        } else {
            didAttemptRun = true
        }
    }
    
    // swiftlint:disable identifier_name
    @_spi(SendbirdInternal) public func execute() {
        state = .executing
        let _task = task
        _task?(self)
        task = nil
        if synchronous {
            complete()
        }
    }
    // swiftlint:enable identifier_name
    
    @_spi(SendbirdInternal) public func provisionalComplete() {
        state = .finished
    }
    
    @_spi(SendbirdInternal) public func complete() {
        if !isFinished {
            provisionalComplete()
        }
    }
}
