//
//  CompletionGuard.swift
//  SendbirdChat
//
//  Created by Jed Gyeong on 8/21/25.
//

import Foundation

/// A utility class that ensures a completion handler is called exactly once.
/// This is useful for preventing race conditions where the same completion handler
/// might be called from multiple code paths concurrently.
///
/// Example use cases:
/// - Timeout handlers with normal completion handlers
/// - Retry mechanisms where both attempts might succeed
/// - Any scenario where duplicate completions could cause issues (like resuming a CheckedContinuation twice)
///
/// Usage example:
/// ```
/// let guard = CompletionGuard()
///
/// // In timeout handler
/// guard.finishOnce { completion?(nil, TimeoutError()) }
///
/// // In normal completion
/// guard.finishOnce { completion?(result, nil) }
/// ```
class CompletionGuard {
    /// Internal flag indicating whether the completion handler has already been called
    private var _hasCompleted = false
    
    /// Lock to ensure thread safety when checking and updating the completion state
    private let lock = NSLock()
    
    /// Executes the provided completion handler only if this is the first call to this method.
    /// Subsequent calls will be ignored.
    ///
    /// - Parameter completionHandler: The completion handler to execute once
    /// - Thread Safety: This method is thread-safe and can be called from multiple threads
    func finishOnce(_ completionHandler: () -> Void) {
        lock.lock()
        guard !_hasCompleted else {
            lock.unlock()
            return
        }
        _hasCompleted = true
        lock.unlock()
        
        completionHandler()
    }
}
