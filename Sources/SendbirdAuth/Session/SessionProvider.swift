//
//  SessionProvider.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 2026/02/02.
//

import Foundation

/// 세션 공유를 위한 프로토콜
/// 한 시점에 하나의 세션만 활성화됨
@_spi(SendbirdInternal) public protocol SessionProvider {
    func setSession(_ session: Session?, for userId: String)
    func loadSession(for userId: String) -> Session?
    func onSessionChanged(_ handler: @escaping (Session?, String?) -> Void)
}

/// UserDefaults 영속성을 포함한 세션 공유 구현체
@_spi(SendbirdInternal) public class PersistentSessionProvider: SessionProvider {
    @_spi(SendbirdInternal) public static let shared = PersistentSessionProvider()

    private let queue = SafeSerialQueue(label: "com.sendbird.session.provider")
    private var handlers: [(Session?, String?) -> Void] = []

    private var session: Session?
    @_spi(SendbirdInternal) public private(set) var userId: String?
    @_spi(SendbirdInternal) public init() {}

    /// UserDefaults에서 세션 복원
    @discardableResult
    @_spi(SendbirdInternal) public func loadSession(for userId: String) -> Session? {
        queue.sync {
            if let session {
                return session
            } else {
                guard let savedSession = Session.buildFromUserDefaults(for: userId) else {
                    return nil
                }

                self.session = savedSession
                return savedSession
            }
        }
    }

    @_spi(SendbirdInternal) public func setSession(_ session: Session?, for userId: String) {
        guard !userId.isEmpty else {
            return
        }
        
        queue.async {
            self.session = session
            self.userId = userId

            if let session = session {
                Session.saveToUserDefaults(session: session, userId: userId)
            } else {
                Session.clearUserDefaults()
            }

            self.notifyHandlers(session: session, userId: userId)
        }
    }

    @_spi(SendbirdInternal) public func onSessionChanged(_ handler: @escaping (Session?, String?) -> Void) {
        queue.async {
            self.handlers.append(handler)
        }
    }

    // MARK: - Private

    private func notifyHandlers(session: Session?, userId: String?) {
        let currentHandlers = queue.sync { handlers }
        currentHandlers.forEach { $0(session, userId) }
    }
}
