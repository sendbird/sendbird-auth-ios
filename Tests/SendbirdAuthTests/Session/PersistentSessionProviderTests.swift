import XCTest
@_spi(SendbirdInternal) @testable import SendbirdAuthSDK

final class PersistentSessionProviderTests: XCTestCase {

    private let sessionKey = "test-session-key"
    private let userId = "testUser"

    private var sut: PersistentSessionProvider!

    override func setUp() {
        super.setUp()
        sut = PersistentSessionProvider()
        Session.clearUserDefaults()
    }

    override func tearDown() {
        Session.clearUserDefaults()
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState_sessionIsNil() {
        XCTAssertNil(sut.loadSession(for: userId))
        XCTAssertNil(sut.userId)
    }

    // MARK: - setSession

    func testSetSession_storesSessionAndUserId() {
        // Given
        let session = Session(key: sessionKey, services: [.chat])
        let expectation = expectation(description: "Session should be set")

        sut.onSessionChanged { _ in
            expectation.fulfill()
        }

        // When
        sut.setSession(session, for: userId)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(sut.loadSession(for: userId)?.key, sessionKey)
        XCTAssertEqual(sut.userId, userId)
    }

    func testSetSession_withNil_clearsSession() {
        // Given
        let session = Session(key: sessionKey, services: [.chat])
        let setExpectation = expectation(description: "Session should be set")
        let clearExpectation = expectation(description: "Session should be cleared")
        var callCount = 0

        sut.onSessionChanged { _ in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else if callCount == 2 {
                clearExpectation.fulfill()
            }
        }
        sut.setSession(session, for: userId)
        wait(for: [setExpectation], timeout: 1.0)

        // When
        sut.setSession(nil, for: userId)

        // Then
        wait(for: [clearExpectation], timeout: 1.0)
        XCTAssertNil(sut.loadSession(for: userId))
        XCTAssertEqual(sut.userId, userId)
    }

    func testSetSession_persistsToUserDefaults() {
        // Given
        let session = Session(key: sessionKey, services: [.chat, .feed])
        let expectation = expectation(description: "Session should be set")

        sut.onSessionChanged { _ in
            expectation.fulfill()
        }

        // When
        sut.setSession(session, for: userId)
        wait(for: [expectation], timeout: 1.0)

        // Then - verify persistence by loading in new instance
        let newProvider = PersistentSessionProvider()
        let loadedSession = newProvider.loadSession(for: userId)

        XCTAssertNotNil(loadedSession)
        XCTAssertEqual(loadedSession?.key, sessionKey)
    }

    // MARK: - loadSession

    func testLoadSession_withValidUserId_restoresSession() {
        // Given - 다른 인스턴스에서 저장
        let otherProvider = PersistentSessionProvider()
        let session = Session(key: sessionKey, services: [.chat])
        let expectation = expectation(description: "Session should be set")

        otherProvider.onSessionChanged { _ in
            expectation.fulfill()
        }
        otherProvider.setSession(session, for: userId)
        wait(for: [expectation], timeout: 1.0)

        // When - 새 인스턴스에서 로드
        let loadedSession = sut.loadSession(for: userId)

        // Then
        XCTAssertNotNil(loadedSession)
        XCTAssertEqual(loadedSession?.key, sessionKey)
        XCTAssertEqual(sut.loadSession(for: userId)?.key, sessionKey)
        XCTAssertEqual(sut.userId, userId)
    }

    func testLoadSession_withDifferentUserId_returnsNil() {
        // Given
        let session = Session(key: sessionKey, services: [.chat])
        let expectation = expectation(description: "Session should be set")

        sut.onSessionChanged { _ in
            expectation.fulfill()
        }
        sut.setSession(session, for: userId)
        wait(for: [expectation], timeout: 1.0)

        // When
        let newProvider = PersistentSessionProvider()
        let loadedSession = newProvider.loadSession(for: "differentUser")

        // Then
        XCTAssertNil(loadedSession)
    }

    func testLoadSession_withNoStoredSession_returnsNil() {
        // When
        let loadedSession = sut.loadSession(for: "nonExistentUser")

        // Then
        XCTAssertNil(loadedSession)
    }

    // MARK: - onSessionChanged

    func testOnSessionChanged_notifiesHandler() {
        // Given
        let expectation = expectation(description: "Handler should be called")
        var receivedSession: Session?

        sut.onSessionChanged { session in
            receivedSession = session
            expectation.fulfill()
        }

        // When
        let session = Session(key: sessionKey, services: [.chat])
        sut.setSession(session, for: userId)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedSession?.key, sessionKey)
    }

    func testOnSessionChanged_notifiesMultipleHandlers() {
        // Given
        let expectation1 = expectation(description: "Handler 1 should be called")
        let expectation2 = expectation(description: "Handler 2 should be called")

        sut.onSessionChanged { _ in expectation1.fulfill() }
        sut.onSessionChanged { _ in expectation2.fulfill() }

        // When
        let session = Session(key: sessionKey, services: [.chat])
        sut.setSession(session, for: userId)

        // Then
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }

    func testOnSessionChanged_notifiesOnClear() {
        // Given
        let session = Session(key: sessionKey, services: [.chat])
        let setExpectation = expectation(description: "Session should be set")
        let clearExpectation = expectation(description: "Handler should be called on clear")
        var callCount = 0
        var receivedSession: Session?

        sut.onSessionChanged { session in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else if callCount == 2 {
                receivedSession = session
                clearExpectation.fulfill()
            }
        }

        sut.setSession(session, for: userId)
        wait(for: [setExpectation], timeout: 1.0)

        // When
        sut.setSession(nil, for: userId)

        // Then
        wait(for: [clearExpectation], timeout: 1.0)
        XCTAssertNil(receivedSession)
    }

    // MARK: - Shared Instance

    func testSharedInstance_isSingleton() {
        let instance1 = PersistentSessionProvider.shared
        let instance2 = PersistentSessionProvider.shared

        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - hasRefreshedSession

    func testHasRefreshedSession_whenStoredSessionDiffers_returnsTrue() {
        // Given
        let storedSession = Session(key: "v2", services: [.chat])
        let currentSession = Session(key: "v1", services: [.chat])
        let expectation = expectation(description: "Session should be set")

        sut.onSessionChanged { _ in expectation.fulfill() }
        sut.setSession(storedSession, for: userId)
        wait(for: [expectation], timeout: 1.0)

        // When
        let result = sut.hasRefreshedSession(current: currentSession)

        // Then
        XCTAssertTrue(result)
    }

    func testHasRefreshedSession_whenStoredSessionSame_returnsFalse() {
        // Given
        let session = Session(key: "v1", services: [.chat])
        let expectation = expectation(description: "Session should be set")

        sut.onSessionChanged { _ in expectation.fulfill() }
        sut.setSession(session, for: userId)
        wait(for: [expectation], timeout: 1.0)

        // When
        let result = sut.hasRefreshedSession(current: session)

        // Then
        XCTAssertFalse(result)
    }

    func testHasRefreshedSession_whenNoStoredSession_returnsFalse() {
        // Given
        let currentSession = Session(key: "v1", services: [.chat])

        // When
        let result = sut.hasRefreshedSession(current: currentSession)

        // Then
        XCTAssertFalse(result)
    }

    // MARK: - submitRefreshedSession

    func testSubmitRefreshedSession_withNewKey_acceptsAndNotifies() {
        // Given
        let newSession = Session(key: "v2", services: [.chat])
        let refreshExpectation = expectation(description: "Handler called")
        var receivedSession: Session?

        sut.onSessionChanged { session in
            receivedSession = session
            refreshExpectation.fulfill()
        }

        // When
        let result = sut.submitRefreshedSession(newSession)

        // Then
        wait(for: [refreshExpectation], timeout: 1.0)
        XCTAssertTrue(result)
        XCTAssertEqual(receivedSession?.key, "v2")
    }

    func testSubmitRefreshedSession_withKnownKey_rejects() {
        // Given
        let session = Session(key: "v1", services: [.chat])
        let setExpectation = expectation(description: "Session set")
        let refreshExpectation = expectation(description: "Handler should not be called again")
        refreshExpectation.isInverted = true
        var callCount = 0

        sut.onSessionChanged { _ in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else {
                refreshExpectation.fulfill()
            }
        }
        sut.setSession(session, for: userId)
        wait(for: [setExpectation], timeout: 1.0)

        // When - try to submit same session again (rollback attempt)
        let result = sut.submitRefreshedSession(session)

        // Then
        wait(for: [refreshExpectation], timeout: 0.5)
        XCTAssertFalse(result)
    }

    func testSubmitRefreshedSession_rollbackPrevention() {
        // Given - v1 -> v2 -> try v1 again
        let v1Session = Session(key: "v1", services: [.chat])
        let v2Session = Session(key: "v2", services: [.chat])
        let setExpectation = expectation(description: "Initial session set")
        let v2Expectation = expectation(description: "v2 session set")
        var callCount = 0

        sut.onSessionChanged { _ in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else if callCount == 2 {
                v2Expectation.fulfill()
            }
        }
        sut.setSession(v1Session, for: userId)
        wait(for: [setExpectation], timeout: 1.0)

        // Submit v2 - should succeed
        let v2Result = sut.submitRefreshedSession(v2Session)
        XCTAssertTrue(v2Result)
        wait(for: [v2Expectation], timeout: 1.0)

        // When - try to rollback to v1
        let rollbackResult = sut.submitRefreshedSession(v1Session)

        // Then
        XCTAssertFalse(rollbackResult)
        XCTAssertEqual(sut.loadSession(for: userId)?.key, "v2")
    }

    // MARK: - knownKeys Management

    func testKnownKeys_clearedOnUserChange() {
        // Given
        let session = Session(key: "v1", services: [.chat])
        let setExpectation = expectation(description: "Session set")
        let newUserExpectation = expectation(description: "New user session set")
        var callCount = 0

        sut.onSessionChanged { _ in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else if callCount == 2 {
                newUserExpectation.fulfill()
            }
        }
        sut.setSession(session, for: userId)
        wait(for: [setExpectation], timeout: 1.0)

        // When - change user
        sut.setSession(nil, for: "differentUser")
        wait(for: [newUserExpectation], timeout: 1.0)

        // Then - same key should be accepted again for new user
        let result = sut.submitRefreshedSession(session)
        XCTAssertTrue(result) // knownKeys was cleared, so v1 is new again
    }

    // MARK: - Scenario Tests

    func testScenario1_simultaneousRefresh() {
        // Simulates: Chat and Desk SDK both get 401 at the same time

        // Given - initial session v1
        let v1Session = Session(key: "v1", services: [.chat])
        let setExpectation = expectation(description: "Initial session set")
        let v2Expectation = expectation(description: "v2 session set")
        var callCount = 0

        sut.onSessionChanged { _ in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else if callCount == 2 {
                v2Expectation.fulfill()
            }
        }
        sut.setSession(v1Session, for: userId)
        wait(for: [setExpectation], timeout: 1.0)

        // When - both SDKs call hasRefreshedSession with v1
        let chatResult = sut.hasRefreshedSession(current: v1Session)
        let deskResult = sut.hasRefreshedSession(current: v1Session)

        // Then - both get false (refresh needed)
        XCTAssertFalse(chatResult)
        XCTAssertFalse(deskResult)

        // When - Chat SDK refreshes and submits v2
        let v2Session = Session(key: "v2", services: [.chat])
        let refreshResult = sut.submitRefreshedSession(v2Session)

        // Then - submission accepted
        XCTAssertTrue(refreshResult)
        wait(for: [v2Expectation], timeout: 1.0)
        XCTAssertEqual(sut.loadSession(for: userId)?.key, "v2")
    }

    func testScenario2_alreadyRefreshedSession() {
        // Simulates: Desk SDK has old v1, but provider already has v2

        // Given - stored session is v2
        let v2Session = Session(key: "v2", services: [.chat])
        let setExpectation = expectation(description: "Session set")

        sut.onSessionChanged { _ in setExpectation.fulfill() }
        sut.setSession(v2Session, for: userId)
        wait(for: [setExpectation], timeout: 1.0)

        // When - Desk SDK calls hasRefreshedSession with old v1
        let v1Session = Session(key: "v1", services: [.chat])
        let result = sut.hasRefreshedSession(current: v1Session)

        // Then - returns true (no refresh needed, already refreshed)
        XCTAssertTrue(result)
    }
}
