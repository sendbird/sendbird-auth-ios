//
//  MockInstance.swift
//  SendbirdChat
//
//  Created by Kai Lee on 2/10/25.
//

#if TESTCASE
import Foundation

/// A thread-safe registry for disposable mock instances used for testing.
/// Once an instance is retrieved, it is removed from the registry.
struct MockInstance {
    private static let lock = NSLock()
    private static var registry: [String: Any] = [:]

    /// Registers a new instance for the specified key.
    /// - Parameters:
    ///   - key: A type-safe key representing the instance.
    ///   - instance: The instance to register.
    static func register<T>(key: MockKey<T>, instance: T) {
        lock.lock()
        defer { lock.unlock() }
        registry[key.rawValue] = instance
    }

    /// Retrieves and removes the instance for the specified key.
    /// - Parameter key: A type-safe key representing the instance.
    /// - Returns: The instance if available, nil otherwise.
    static func pop<T>(key: MockKey<T>) -> T? {
        lock.lock()
        defer { lock.unlock() }
        guard let instance = registry[key.rawValue] as? T else {
            return nil
        }
        registry[key.rawValue] = nil
        return instance
    }
}

// MARK: - MockKey
/// A type-safe key for storing and retrieving disposable mock instances.
struct MockKey<T> {
    let rawValue: String
    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension MockKey where T == ChatWebSocketEngine {
    static let chatWebSocketEngine = MockKey<ChatWebSocketEngine>("chatWebSocketEngine")
}
#endif
