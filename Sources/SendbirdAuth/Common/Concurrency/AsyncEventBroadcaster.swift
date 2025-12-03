//
//  AsyncEventBroadcaster.swift
//  SendbirdChat
//
//  Created by Kai Lee on 9/14/25.
//

import Foundation

actor AsyncEventBroadcaster<T> {
    struct Subscriber {
        let id: UUID
        let continuation: AsyncStream<T>.Continuation
    }
    
    private var subscribers: [Subscriber] = []
    private let bufferingPolicy: AsyncStream<T>.Continuation.BufferingPolicy
    
    init(
        bufferingPolicy: AsyncStream<T>.Continuation.BufferingPolicy = .bufferingNewest(256)
    ) {
        self.bufferingPolicy = bufferingPolicy
    }
    
    func makeStream() -> AsyncStream<T> {
        let id = UUID()
        
        let (stream, continuation) = AsyncStream.makeStream(
            of: T.self,
            bufferingPolicy: self.bufferingPolicy
        )
        
        continuation.onTermination = { @Sendable [weak self] _ in
            Task { [id] in
                await self?.removeSubscriber(withId: id)
            }
        }
        
        subscribers.append(Subscriber(id: id, continuation: continuation))
        
        return stream
    }
    
    func yield(_ value: T) {
        guard !subscribers.isEmpty else {
            Logger.client.debug("No subscribers to receive value. Value dropped: \(value)")
            return
        }
        distribute(value)
    }
    
    func finish() {
        terminateAll()
    }
    
    nonisolated func finishAsync() {
        Task { await self.finish() }
    }
    
    // MARK: - Private methods
    
    private func distribute(_ value: T) {
        subscribers.forEach { $0.continuation.yield(value) }
    }
    
    private func terminateAll() {
        for subscriber in subscribers {
            subscriber.continuation.finish()
        }
        subscribers.removeAll()
    }

    private func removeSubscriber(withId id: UUID) {
        subscribers.removeAll { $0.id == id }
    }
}

#if DEBUG
extension AsyncEventBroadcaster {
    /// For tests: current number of active subscribers
    func getSubscribers() -> [Subscriber] {
        subscribers
    }
    
    @_spi(SendbirdInternal) public func simulateYield(_ value: T) {
        yield(value)
    }
}
#endif
