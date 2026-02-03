//
//  SessionProvider.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 2026/02/02.
//

import Foundation

@_spi(SendbirdInternal) public protocol SessionProvider: AnyObject {
    func session(for userId: String) -> Session?
    func setSession(_ session: Session?, for userId: String)
    func onSessionChanged(_ handler: @escaping (Session?, String) -> Void)
}

/// SDK 제공 기본 구현체 - UserDefaults 영속성 포함
@_spi(SendbirdInternal) public class SharedSessionProvider: SessionProvider {
    @_spi(SendbirdInternal) public static let shared = SharedSessionProvider()

    @InternalAtomic private var sessions: [String: Session] = [:]
    private var handlers: [(Session?, String) -> Void] = []
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

        // Handler들에게 통지
        notifyHandlers(session: session, userId: userId)
    }

    @_spi(SendbirdInternal) public func onSessionChanged(_ handler: @escaping (Session?, String) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        handlers.append(handler)
    }

    private func notifyHandlers(session: Session?, userId: String) {
        lock.lock()
        let currentHandlers = handlers
        lock.unlock()

        currentHandlers.forEach { $0(session, userId) }
    }
}
