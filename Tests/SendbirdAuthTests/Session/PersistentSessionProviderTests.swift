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
        let observer = MockSessionObserver()
        let expectation = expectation(description: "Session should be set")
        observer.onSessionChange = { _ in expectation.fulfill() }
        sut.addSessionObserver(observer)

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
        let observer = MockSessionObserver()
        let setExpectation = expectation(description: "Session should be set")
        let clearExpectation = expectation(description: "Session should be cleared")
        var callCount = 0

        observer.onSessionChange = { _ in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else if callCount == 2 {
                clearExpectation.fulfill()
            }
        }
        sut.addSessionObserver(observer)
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
        let observer = MockSessionObserver()
        let expectation = expectation(description: "Session should be set")
        observer.onSessionChange = { _ in expectation.fulfill() }
        sut.addSessionObserver(observer)

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
        let observer = MockSessionObserver()
        let expectation = expectation(description: "Session should be set")
        observer.onSessionChange = { _ in expectation.fulfill() }
        otherProvider.addSessionObserver(observer)
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
        let observer = MockSessionObserver()
        let expectation = expectation(description: "Session should be set")
        observer.onSessionChange = { _ in expectation.fulfill() }
        sut.addSessionObserver(observer)
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

    // MARK: - SessionObserver

    func testAddSessionObserver_notifiesObserver() {
        // Given
        let expectation = expectation(description: "Observer should be called")
        let observer = MockSessionObserver()
        var receivedSession: Session?
        observer.onSessionChange = { session in
            receivedSession = session
            expectation.fulfill()
        }
        sut.addSessionObserver(observer)

        // When
        let session = Session(key: sessionKey, services: [.chat])
        sut.setSession(session, for: userId)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedSession?.key, sessionKey)
    }

    func testAddSessionObserver_notifiesMultipleObservers() {
        // Given
        let expectation1 = expectation(description: "Observer 1 should be called")
        let expectation2 = expectation(description: "Observer 2 should be called")

        let observer1 = MockSessionObserver()
        observer1.onSessionChange = { _ in expectation1.fulfill() }
        let observer2 = MockSessionObserver()
        observer2.onSessionChange = { _ in expectation2.fulfill() }

        sut.addSessionObserver(observer1)
        sut.addSessionObserver(observer2)

        // When
        let session = Session(key: sessionKey, services: [.chat])
        sut.setSession(session, for: userId)

        // Then
        wait(for: [expectation1, expectation2], timeout: 1.0)
    }

    func testAddSessionObserver_notifiesOnClear() {
        // Given
        let session = Session(key: sessionKey, services: [.chat])
        let observer = MockSessionObserver()
        let setExpectation = expectation(description: "Session should be set")
        let clearExpectation = expectation(description: "Observer should be called on clear")
        var callCount = 0
        var receivedSession: Session?

        observer.onSessionChange = { session in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else if callCount == 2 {
                receivedSession = session
                clearExpectation.fulfill()
            }
        }
        sut.addSessionObserver(observer)

        sut.setSession(session, for: userId)
        wait(for: [setExpectation], timeout: 1.0)

        // When
        sut.setSession(nil, for: userId)

        // Then
        wait(for: [clearExpectation], timeout: 1.0)
        XCTAssertNil(receivedSession)
    }

    func testAddSessionObserver_preventsDuplicateRegistration() {
        // Given
        let observer = MockSessionObserver()
        var callCount = 0
        let expectation = expectation(description: "Observer should be called once")

        observer.onSessionChange = { _ in
            callCount += 1
            expectation.fulfill()
        }

        sut.addSessionObserver(observer)
        sut.addSessionObserver(observer) // duplicate

        // When
        let session = Session(key: sessionKey, services: [.chat])
        sut.setSession(session, for: userId)

        // Then
        wait(for: [expectation], timeout: 1.0)
        // Small delay to ensure no extra calls
        let noExtraCall = XCTestExpectation(description: "No extra call")
        noExtraCall.isInverted = true
        wait(for: [noExtraCall], timeout: 0.3)
        XCTAssertEqual(callCount, 1)
    }

    func testRemoveSessionObserver_stopsNotification() {
        // Given
        let observer = MockSessionObserver()
        let notCalledExpectation = expectation(description: "Observer should not be called")
        notCalledExpectation.isInverted = true
        observer.onSessionChange = { _ in notCalledExpectation.fulfill() }

        sut.addSessionObserver(observer)
        sut.removeSessionObserver(observer)

        // Small delay to ensure async removeSessionObserver completes
        let removeDelay = expectation(description: "Remove delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { removeDelay.fulfill() }
        wait(for: [removeDelay], timeout: 1.0)

        // When
        let session = Session(key: sessionKey, services: [.chat])
        sut.setSession(session, for: userId)

        // Then
        wait(for: [notCalledExpectation], timeout: 0.5)
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
        let observer = MockSessionObserver()
        let expectation = expectation(description: "Session should be set")
        observer.onSessionChange = { _ in expectation.fulfill() }
        sut.addSessionObserver(observer)
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
        let observer = MockSessionObserver()
        let expectation = expectation(description: "Session should be set")
        observer.onSessionChange = { _ in expectation.fulfill() }
        sut.addSessionObserver(observer)
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
        let observer = MockSessionObserver()
        let refreshExpectation = expectation(description: "Observer called")
        var receivedSession: Session?

        observer.onSessionChange = { session in
            receivedSession = session
            refreshExpectation.fulfill()
        }
        sut.addSessionObserver(observer)

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
        let observer = MockSessionObserver()
        let setExpectation = expectation(description: "Session set")
        let refreshExpectation = expectation(description: "Observer should not be called again")
        refreshExpectation.isInverted = true
        var callCount = 0

        observer.onSessionChange = { _ in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else {
                refreshExpectation.fulfill()
            }
        }
        sut.addSessionObserver(observer)
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
        let observer = MockSessionObserver()
        let setExpectation = expectation(description: "Initial session set")
        let v2Expectation = expectation(description: "v2 session set")
        var callCount = 0

        observer.onSessionChange = { _ in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else if callCount == 2 {
                v2Expectation.fulfill()
            }
        }
        sut.addSessionObserver(observer)
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
        let observer = MockSessionObserver()
        let setExpectation = expectation(description: "Session set")
        let newUserExpectation = expectation(description: "New user session set")
        var callCount = 0

        observer.onSessionChange = { _ in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else if callCount == 2 {
                newUserExpectation.fulfill()
            }
        }
        sut.addSessionObserver(observer)
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
        let observer = MockSessionObserver()
        let setExpectation = expectation(description: "Initial session set")
        let v2Expectation = expectation(description: "v2 session set")
        var callCount = 0

        observer.onSessionChange = { _ in
            callCount += 1
            if callCount == 1 {
                setExpectation.fulfill()
            } else if callCount == 2 {
                v2Expectation.fulfill()
            }
        }
        sut.addSessionObserver(observer)
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
        let observer = MockSessionObserver()
        let setExpectation = expectation(description: "Session set")
        observer.onSessionChange = { _ in setExpectation.fulfill() }
        sut.addSessionObserver(observer)
        sut.setSession(v2Session, for: userId)
        wait(for: [setExpectation], timeout: 1.0)

        // When - Desk SDK calls hasRefreshedSession with old v1
        let v1Session = Session(key: "v1", services: [.chat])
        let result = sut.hasRefreshedSession(current: v1Session)

        // Then - returns true (no refresh needed, already refreshed)
        XCTAssertTrue(result)
    }
}

// MARK: - Mock

private class MockSessionObserver: SessionObserver {
    var onSessionChange: ((Session?) -> Void)?

    func sessionDidChange(_ session: Session?) {
        onSessionChange?(session)
    }
}
