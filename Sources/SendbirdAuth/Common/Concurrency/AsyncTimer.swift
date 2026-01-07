//
//  AsyncTimer.swift
//  SendbirdChat
//
//  Created by Kai Lee on 10/1/25.
//

import Foundation

actor AsyncTimer {
    
    // MARK: - Properties & State
    
    nonisolated let identifier: String
    private let timeInterval: TimeInterval
    
    enum State: String {
        case pending, running, expired, stopped
    }
    
    private(set) var state: State = .pending
    var isValid: Bool {
        state == .running
    }
    
    private let tickingStreamContinuation: AsyncStream<Void>.Continuation?
    private let tickingStream: AsyncStream<Void>
    
    private var timerTask: Task<Void, Never>?

    init(
        timeInterval: TimeInterval,
        identifier: String = UUID().uuidString
    ) {
        self.timeInterval = timeInterval
        self.identifier = identifier
        
        (self.tickingStream, self.tickingStreamContinuation) = AsyncStream.makeStream(
            of: Void.self,
            bufferingPolicy: .bufferingNewest(1) /// Buffer only the latest tick if not consumed yet
        )
    }
    
    // MARK: - Control Methods
    
    @discardableResult
    nonisolated func run(
        repeats: Bool = false,
        work: @Sendable @escaping () async -> Void
    ) -> AsyncTimer {
        Task { [weak self] in
            guard let self else { return }
            
            let stream = await self.start(repeats: repeats)
            await self.consumeTicks(from: stream, repeats: repeats, work: work)
        }
        
        return self
    }
    
    func stop() throws(AuthClientError) {
        switch state {
        case .running:
            state = .stopped
            timerTask?.cancel()
        case .stopped:
            throw AuthClientError.timerWasAlreadyDone
        case .expired:
            throw AuthClientError.timerWasExpired
        case .pending:
            state = .stopped
        }
    }
        
    /// Stops the timer unconditionally regardless of its state
    func abort() {
        state = .stopped
        timerTask?.cancel()
    }
    
    // MARK: - Internal Logic
    
    private func start(repeats: Bool) -> AsyncStream<Void> {
        if state == .pending {
            state = .running
            timerTask = Task {
                await runTimerLoop(repeats: repeats)
            }
        }
        
        return tickingStream
    }

    private func consumeTicks(
        from stream: AsyncStream<Void>,
        repeats: Bool,
        work: @Sendable @escaping () async -> Void
    ) async {
        for await _ in stream {
            await work()
            if !repeats { break }
        }
    }

    private func runTimerLoop(repeats: Bool) async {
        guard let tickingStreamContinuation else { return }
        
        defer {
            tickingStreamContinuation.finish()
            self.timerTask = nil
            if self.state == .running {
                self.state = .stopped
            }
        }
        
        do {
            if repeats {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(timeInterval))
                    tickingStreamContinuation.yield(())
                }
            } else {
                try await Task.sleep(for: .seconds(timeInterval))
                if !Task.isCancelled {
                    tickingStreamContinuation.yield(())
                    self.state = .expired
                }
            }
        } catch {
            // Task cancelled
        }
    }
}

// MARK: - Static Convenience Wrappers
extension AsyncTimer {
    /// Creates and starts an `AsyncTimer` that runs the provided work
    /// after the specified interval.
    @discardableResult
    nonisolated static func run(
        interval: TimeInterval,
        identifier: String = UUID().uuidString,
        repeats: Bool = false,
        work: @Sendable @escaping () async -> Void
    ) -> AsyncTimer {
        let timer = AsyncTimer(
            timeInterval: interval,
            identifier: identifier
        )
        
        return timer.run(repeats: repeats, work: work)
    }
}
