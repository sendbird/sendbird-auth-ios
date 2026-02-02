//
//  SessionProvider.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 2026/02/02.
//

import Foundation

@_spi(SendbirdInternal) public protocol SessionProviderObserver: AnyObject {
    func sessionDidChange(_ session: Session?, for userId: String)
}

@_spi(SendbirdInternal) public protocol SessionProvider: AnyObject {
    func session(for userId: String) -> Session?
    func setSession(_ session: Session?, for userId: String)
    func addObserver(_ observer: SessionProviderObserver)
    func removeObserver(_ observer: SessionProviderObserver)
}

/// SDK 제공 기본 구현체 - UserDefaults 영속성 포함
@_spi(SendbirdInternal) public class SharedSessionProvider: SessionProvider {
    @_spi(SendbirdInternal) public static let shared = SharedSessionProvider()

    @InternalAtomic private var sessions: [String: Session] = [:]
    private let observers = NSHashTable<AnyObject>.weakObjects()
    private let lock = NSLock()

    @_spi(SendbirdInternal) public init() {}

    @_spi(SendbirdInternal) public func session(for userId: String) -> Session? {
        if let cached = sessions[userId] {
            return cached
        }
        // UserDefaults에서 로드 (기존 Session.buildFromUserDefaults 활용)
        if let stored = Session.buildFromUserDefaults(for: userId) {
            sessions[userId] = stored
            return stored
        }
        return nil
    }

    @_spi(SendbirdInternal) public func setSession(_ session: Session?, for userId: String) {
        sessions[userId] = session

        // UserDefaults에 저장
        if let session = session {
            Session.saveToUserDefaults(session: session, userId: userId)
        } else {
            Session.clearUserDefaults()
        }

        // Observer들에게 통지
        notifyObservers(session: session, userId: userId)
    }

    @_spi(SendbirdInternal) public func addObserver(_ observer: SessionProviderObserver) {
        lock.lock()
        defer { lock.unlock() }
        observers.add(observer)
    }

    @_spi(SendbirdInternal) public func removeObserver(_ observer: SessionProviderObserver) {
        lock.lock()
        defer { lock.unlock() }
        observers.remove(observer)
    }

    private func notifyObservers(session: Session?, userId: String) {
        lock.lock()
        let currentObservers = observers.allObjects
        lock.unlock()

        currentObservers
            .compactMap { $0 as? SessionProviderObserver }
            .forEach { $0.sessionDidChange(session, for: userId) }
    }
}
