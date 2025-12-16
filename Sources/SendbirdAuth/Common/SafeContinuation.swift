//
//  SafeContinuation.swift
//  SendbirdAuth
//
//  Provides a safe wrapper around CheckedContinuation that prevents double-resume crashes.
//

import Foundation

/// A thread-safe wrapper around CheckedContinuation that ensures resume is called only once.
@_spi(SendbirdInternal) public final class SafeThrowingContinuation<T> {
    private let continuation: CheckedContinuation<T, Error>
    private let completionGuard: CompletionGuard

    fileprivate init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
        completionGuard = CompletionGuard()
    }

    /// Resumes the continuation with a successful result.
    /// Subsequent calls are safely ignored.
    public func resume() where T == Void {
        completionGuard.finishOnce {
            continuation.resume()
        }
    }

    /// Resumes the continuation with a successful result.
    /// Subsequent calls are safely ignored.
    public func resume(returning value: T) {
        completionGuard.finishOnce {
            continuation.resume(returning: value)
        }
    }

    /// Resumes the continuation with an error.
    /// Subsequent calls are safely ignored.
    public func resume(throwing error: Error) {
        completionGuard.finishOnce {
            continuation.resume(throwing: error)
        }
    }
}

/// Creates a safe continuation that prevents double-resume crashes.
///
/// Usage:
/// ```swift
/// try await withSafeThrowingContinuation { continuation in
///     requestQueue.post(...) { result in
///         switch result {
///         case .success:
///             continuation.resume()  // Safe even if called multiple times
///         case .failure(let error):
///             continuation.resume(throwing: error)
///         }
///     }
/// }
/// ```
@_spi(SendbirdInternal) public func withSafeThrowingContinuation<T>(
    _ body: (SafeThrowingContinuation<T>) -> Void
) async throws -> T {
    return try await withCheckedThrowingContinuation { continuation in
        let safeContinuation = SafeThrowingContinuation(continuation)
        body(safeContinuation)
    }
}
