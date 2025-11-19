//
//  SBTimerBoard.swift
//
//
//  Created by sendbird-young on 17/11/2019.
//
import Foundation

package protocol SBTimerBoardDelegate: AnyObject {
    func add(timer: SBTimer)
    func remove(timer: SBTimer)
}

extension SBTimerBoardDelegate {
    func add(timer: SBTimer) {}
    func remove(timer: SBTimer) {}
}

package class SBTimerBoard: SBTimerBoardDelegate {
    package var timers: [SBTimer] {
        self.timerQueue.sync {
            return self.mutableTimers.filter { $0.valid }
        }
    }
    
    // This list of timer may contain a mix of valid / invalid timers
    // Invalid timers are removed when `add(timer:)` is called.
    private var mutableTimers: [SBTimer] = []
    private let capacity: Int
    package let timerQueue = SafeSerialQueue(
        label: "com.sendbird.core.common.timer.board.\(UUID().uuidString)"
    )
    
    package var first: SBTimer? { self.timers.first }
    
    package init(capacity: Int = Int(INT_MAX)) {
        self.capacity = capacity
    }
    
    deinit {
        self.stopAll()
    }
    
    package func timer(identifier: String) -> SBTimer? {
        return self.timers.first(where: { $0.identifier == identifier })
    }
    
    package func stopAll() {
        self.timerQueue.sync {
            for timer in self.mutableTimers {
                timer.stop()
            }
        }
    }
    
    // MARK: SBTimer Board Delegate
    package func add(timer: SBTimer) {
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
    
    package func remove(timer: SBTimer) {
        self.timerQueue.sync {
            self.mutableTimers.removeAll { $0 === timer }
        }
    }
}
