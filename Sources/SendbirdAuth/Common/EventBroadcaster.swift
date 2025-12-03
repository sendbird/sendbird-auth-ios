//
//  EventBroadcaster.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/14.
//

import Foundation

@_spi(SendbirdInternal) public protocol EventBroadcaster<DelegateType> {
    associatedtype DelegateType: AnyObject

    var delegates: NSMapTable<NSString, DelegateType> { get }
    var service: QueueService { get }
    var delegateLock: NSLock { get }

    func delegate(forKey key: String) -> DelegateType?

    func addDelegate(_ delegate: DelegateType, forKey key: String)

    func removeDelegate(forKey key: String)

    func removeAllDelegates()

    func callAsFunction(task: @escaping ((DelegateType) -> Void))

    func broadcast<OtherType>(upcast: OtherType, task: @escaping ((OtherType) -> Void))

    func broadcast(task: @escaping ((DelegateType) -> Void))
}

extension EventBroadcaster {
    @_spi(SendbirdInternal) public func delegate(forKey key: String) -> DelegateType? {
        return delegateLock.withLock {
            delegates.object(forKey: key as NSString)
        }
    }

    @_spi(SendbirdInternal) public func addDelegate(_ delegate: DelegateType, forKey key: String) {
        delegateLock.withLock {
            // Remove existing delegate first to safely clean up weak references
            delegates.removeObject(forKey: key as NSString)
            delegates.setObject(delegate, forKey: key as NSString)
        }
    }

    @_spi(SendbirdInternal) public func removeDelegate(forKey key: String) {
        delegateLock.withLock {
            delegates.removeObject(forKey: key as NSString)
        }
    }

    @_spi(SendbirdInternal) public func removeAllDelegates() {
        delegateLock.withLock {
            delegates.removeAllObjects()
        }
    }

    @_spi(SendbirdInternal) public func callAsFunction(task: @escaping ((DelegateType) -> Void)) {
        self.broadcast(task: task)
    }

    @_spi(SendbirdInternal) public func broadcast<OtherType>(upcast: OtherType, task: @escaping ((OtherType) -> Void)) {
        service {
            // Create a thread-safe snapshot of delegates before enumeration
            let snapshot = self.delegateLock.withLock {
                self.delegates.objectEnumerator()?.allObjects
            }

            snapshot?
                .compactMap { $0 as? OtherType }
                .forEach { task($0) }
        }
    }

    @_spi(SendbirdInternal) public func broadcast(task: @escaping ((DelegateType) -> Void)) {
        service {
            // Create a thread-safe snapshot of delegates before enumeration
            let snapshot = self.delegateLock.withLock {
                self.delegates.objectEnumerator()?.allObjects
            }

            let allDelegates = (snapshot as? [DelegateType]) ?? []
            allDelegates.forEach { task($0) }
        }
    }
}
