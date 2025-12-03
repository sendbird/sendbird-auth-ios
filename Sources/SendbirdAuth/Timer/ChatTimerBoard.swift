//
//  SBTimerBoard.swift
//
//
//  Created by sendbird-young on 17/11/2019.
//
import Foundation

@_spi(SendbirdInternal) public protocol SBTimerBoardDelegate: AnyObject {
    func add(timer: SBTimer)
    func remove(timer: SBTimer)
}

extension SBTimerBoardDelegate {
    func add(timer: SBTimer) {}
    func remove(timer: SBTimer) {}
}

@_spi(SendbirdInternal) public class SBTimerBoard: SBTimerBoardDelegate {
    @_spi(SendbirdInternal) public var timers: [SBTimer] {
        self.timerQueue.sync {
            return self.mutableTimers.filter { $0.valid }
        }
    }
    
    // This list of timer may contain a mix of valid / invalid timers
    // Invalid timers are removed when `add(timer:)` is called.
    private var mutableTimers: [SBTimer] = []
    private let capacity: Int
    @_spi(SendbirdInternal) public let timerQueue = SafeSerialQueue(
        label: "com.sendbird.core.common.timer.board.\(UUID().uuidString)"
    )
    
    @_spi(SendbirdInternal) public var first: SBTimer? { self.timers.first }
    
    @_spi(SendbirdInternal) public init(capacity: Int = Int(INT_MAX)) {
        self.capacity = capacity
    }
    
    deinit {
        self.stopAll()
    }
    
    @_spi(SendbirdInternal) public func timer(identifier: String) -> SBTimer? {
        return self.timers.first(where: { $0.identifier == identifier })
    }
    
    @_spi(SendbirdInternal) public func stopAll() {
        self.timerQueue.sync {
            for timer in self.mutableTimers {
                timer.stop()
            }
        }
    }
    
    // MARK: SBTimer Board Delegate
    @_spi(SendbirdInternal) public func add(timer: SBTimer) {
        self.timerQueue.sync {
            let timers = self.mutableTimers
            var validTimers = timers.filter { $0.valid }
            
            if validTimers.count >= self.capacity {
                var count = (validTimers.count - self.capacity + 1)
                
                for timer in validTimers {
                    timer.abort()
                    count -= 1
                    
                    if count == 0 {
                        break
                    }
                }
            }
            
            validTimers.append(timer)
            self.mutableTimers = validTimers
        }
    }
    
    @_spi(SendbirdInternal) public func remove(timer: SBTimer) {
        self.timerQueue.sync {
            self.mutableTimers.removeAll { $0 === timer }
        }
    }
}
