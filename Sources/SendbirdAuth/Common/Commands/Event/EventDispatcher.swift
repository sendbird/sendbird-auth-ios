//
//  EventDispatcher.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

@_spi(SendbirdInternal) public class EventDispatcher {
    @_spi(SendbirdInternal) public var delegates: NSMapTable<NSString, AnyObject>
    @_spi(SendbirdInternal) public var queue: SafeSerialQueue
    @_spi(SendbirdInternal) public var timeout: TimeInterval = 10.0
    
    private var onBeforeDispatchCommandHandler: ((Command) -> Void)?
    
    /// WS event deduplication manager.
    /// - Since: 4.27.0
    private let wsEventDeduplicator: WSEventDeduplicator = WSEventDeduplicator()
    
    @_spi(SendbirdInternal) public lazy var operationQueue: OperationQueue = {
        let operationQueue = OperationQueue()
        operationQueue.name = "com.sendbird.core.event_receiver.\(UUID().uuidString)"
        operationQueue.maxConcurrentOperationCount = 1
        return operationQueue
    }()
    
    @_spi(SendbirdInternal) public let identifier = UUID().uuidString
    
    @_spi(SendbirdInternal) public init() {
        self.delegates = NSMapTable<NSString, AnyObject>(keyOptions: .strongMemory, valueOptions: .weakMemory)
        self.queue = SafeSerialQueue(label: "com.sendbird.core.chat.commandrouter.eventreceiver.\(identifier)")
    }
    
    @_spi(SendbirdInternal) public func add(receivers: [EventDelegate]) {
        receivers.forEach {
            add(receiver: $0, forKey: "\(type(of: $0))_\(identifier)")
        }
    }
    
    @_spi(SendbirdInternal) public func add(receiver: EventDelegate, forKey key: String) {
        delegates.setObject(receiver, forKey: key as NSString)
    }
    
    @_spi(SendbirdInternal) public func remove(forKey key: String) {
        delegates.removeObject(forKey: key as NSString)
    }
    
    @_spi(SendbirdInternal) public func register(deduplicationRules: [WSEventDeduplicationRule]) {
        Logger.client.verbose("Register WS event deduplication rules")
        // Use semaphore to make the below Task bevahe synchronously.
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await self.wsEventDeduplicator.register(deduplicationRules: deduplicationRules)
            semaphore.signal()
        }
        switch semaphore.wait(timeout: .now() + 1) {
        case .success:
            break
        case .timedOut:
            // NOTE: The worst that can happen when this times out is that the handling of this WS event may be duplicated, which is okay from the behavior perspective.
            Logger.client.debug("Semaphore of 1 second timed out while registering deduplication rules.")
        }
    }
    
    @_spi(SendbirdInternal) public func execute(internalEvent: InternalEvent) {
        Logger.client.verbose("Will dispatch event: \(internalEvent)")
        
        // InternalEvent is dispatched from the thread that called dispatch for immediate propagation.
        dispatchableDelegates.forEach { $0.didReceiveInternalEvent(command: internalEvent) }
    }
    
    @_spi(SendbirdInternal) public func dispatch(command: Command, completionHandler: VoidHandler? = nil) {
        onBeforeDispatchCommandHandler?(command)
        
        // InternalEvent is dispatched from the thread that called dispatch for immediate propagation.
        if let command = command as? InternalEvent,
           command.dispatchSynchronously == true {
            execute(internalEvent: command)
            completionHandler?()
            return
        }
        
        Logger.client.verbose("Will dispatch command: \(command)")
        
        // NOTE: queue.async assures serialized dispatches of events.
        queue.async {
            Task { [weak self] in
                guard let self else {
                    return
                }
                
                for delegate in self.dispatchableDelegates {
                    // Skip dispatching events that should be deduplicated
                    if await self.wsEventDeduplicator.shouldIgnore(event: command, for: delegate) {
                        Logger.client.verbose("(deduplication rule) Ignoring \(command) for \(delegate)")
                        continue
                    }
                    if let sbCommand = command as? SBCommand {
                        await delegate.didReceiveSBCommandEvent(command: sbCommand)
                    } else if let internalCommand = command as? InternalEvent {
                        delegate.didReceiveInternalEvent(command: internalCommand)
                    } else {
                        Logger.main.debug("Received a command that is not SBCommand: \(command)")
                    }
                }
                Logger.client.verbose("Completed dispatching command: \(command)")
                
                completionHandler?()
            }
        }
    }
    
    private var dispatchableDelegates: [any EventDelegate] {
        delegates
            .objectEnumerator()?
            .compactMap({ $0 as? EventDelegate })
            .sorted(by: { $0.priority > $1.priority })
        ?? []
    }
}

@_spi(SendbirdInternal) public extension EventDispatcher {
    func onBeforeDispatchCommand(_ handler: ((Command) -> Void)?) {
        onBeforeDispatchCommandHandler = handler
    }
}
