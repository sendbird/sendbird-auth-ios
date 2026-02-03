//
//  SessionProvider.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 2026/02/02.
//

import Foundation

/// 세션 공유를 위한 프로토콜
/// 한 시점에 하나의 세션만 활성화됨
@_spi(SendbirdInternal) public protocol SessionProvider: AnyObject {
    var session: Session? { get }
    var userId: String? { get }

    func setSession(_ session: Session?, for userId: String)
    func loadSession(for userId: String) -> Session?
    func onSessionChanged(_ handler: @escaping (Session?, String?) -> Void)
}

/// UserDefaults 영속성을 포함한 세션 공유 구현체
@_spi(SendbirdInternal) public class PersistentSessionProvider: SessionProvider {
    @_spi(SendbirdInternal) public static let shared = PersistentSessionProvider()

    private let lock = NSLock()
    private var handlers: [(Session?, String?) -> Void] = []

    @_spi(SendbirdInternal) public private(set) var session: Session?
    @_spi(SendbirdInternal) public private(set) var userId: String?

    @_spi(SendbirdInternal) public init() {}

    /// UserDefaults에서 세션 복원
    @discardableResult
    @_spi(SendbirdInternal) public func loadSession(for userId: String) -> Session? {
        guard let savedSession = Session.buildFromUserDefaults(for: userId) else {
            return nil
        }
        lock.lock()
        self.session = savedSession
        self.userId = userId
        lock.unlock()
        return savedSession
    }

    @_spi(SendbirdInternal) public func setSession(_ session: Session?, for userId: String) {
        lock.lock()
        self.session = session
        self.userId = if session != nil { userId } else { nil }
        lock.unlock()

        // UserDefaults에 저장
        if let session = session {
            Session.saveToUserDefaults(session: session, userId: userId)
        } else {
            Session.clearUserDefaults()
        }

        notifyHandlers(session: session, userId: userId)
    }

    @_spi(SendbirdInternal) public func onSessionChanged(_ handler: @escaping (Session?, String?) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        handlers.append(handler)
    }

    // MARK: - Private

    private func notifyHandlers(session: Session?, userId: String?) {
        lock.lock()
        let currentHandlers = handlers
        lock.unlock()

        currentHandlers.forEach { $0(session, userId) }
    }
}
