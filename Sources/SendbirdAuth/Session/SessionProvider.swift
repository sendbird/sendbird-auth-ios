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

    // MARK: - Refresh Coordination

    /// 401 응답 시 호출. 다른 SDK가 이미 갱신한 세션이 있으면 반환, 없으면 nil
    func requestRefresh(current: Session) -> Session?

    /// 토큰 갱신 API 응답 후 호출. 새 세션 채택 여부 반환 (이미 사용된 키면 거부)
    func submitRefreshedSession(_ newSession: Session) -> Bool

    /// 다른 SDK가 갱신한 세션을 수신하기 위한 콜백 등록
    func onSessionRefreshed(_ handler: @escaping (Session) -> Void)
}

/// UserDefaults 영속성을 포함한 세션 공유 구현체
@_spi(SendbirdInternal) public class PersistentSessionProvider: SessionProvider {
    @_spi(SendbirdInternal) public static let shared = PersistentSessionProvider()

    private let queue = SafeSerialQueue(label: "com.sendbird.session.provider")
    private var handlers: [(Session?, String?) -> Void] = []
    private var refreshedHandlers: [(Session) -> Void] = []

    /// 이미 사용된 세션 키 추적 (롤백 방지)
    private var knownKeys: Set<String> = []

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
                self.userId = userId
                knownKeys.insert(savedSession.key)
                return savedSession
            }
        }
    }

    @_spi(SendbirdInternal) public func setSession(_ session: Session?, for userId: String) {
        guard !userId.isEmpty else {
            return
        }

        let handlersToNotify: [(Session?, String?) -> Void] = queue.sync {
            // userId 변경 시 knownKeys 초기화
            if self.userId != userId {
                knownKeys.removeAll()
            }

            self.session = session
            self.userId = userId

            // 새 세션 키를 knownKeys에 추가
            if let sessionKey = session?.key {
                knownKeys.insert(sessionKey)
            }

            if let session = session {
                Session.saveToUserDefaults(session: session, userId: userId)
            } else {
                Session.clearUserDefaults()
            }

            return handlers
        }

        handlersToNotify.forEach { $0(session, userId) }
    }

    @_spi(SendbirdInternal) public func onSessionChanged(_ handler: @escaping (Session?, String?) -> Void) {
        queue.async {
            self.handlers.append(handler)
        }
    }

    // MARK: - Refresh Coordination

    @_spi(SendbirdInternal) public func requestRefresh(current: Session) -> Session? {
        queue.sync {
            // 저장된 세션 키가 다르면 이미 다른 SDK가 갱신함
            if let storedSession = session, storedSession.key != current.key {
                return storedSession
            }
            return nil // 갱신 필요
        }
    }

    @_spi(SendbirdInternal) public func submitRefreshedSession(_ newSession: Session) -> Bool {
        let (accepted, handlersToNotify): (Bool, [(Session) -> Void]) = queue.sync {
            // 이미 사용된 키면 거부 (롤백 방지)
            if knownKeys.contains(newSession.key) {
                return (false, [])
            }

            knownKeys.insert(newSession.key)
            session = newSession

            if let userId = self.userId {
                Session.saveToUserDefaults(session: newSession, userId: userId)
            }

            return (true, refreshedHandlers)
        }

        // 데드락 방지: 핸들러는 sync 블록 바깥에서 호출
        if accepted {
            handlersToNotify.forEach { $0(newSession) }
        }

        return accepted
    }

    @_spi(SendbirdInternal) public func onSessionRefreshed(_ handler: @escaping (Session) -> Void) {
        queue.async {
            self.refreshedHandlers.append(handler)
        }
    }

}
