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

        sut.onSessionChanged { _, _ in
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

        sut.onSessionChanged { _, _ in
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

        sut.onSessionChanged { _, _ in
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

        otherProvider.onSessionChanged { _, _ in
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

        sut.onSessionChanged { _, _ in
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
        var receivedUserId: String?

        sut.onSessionChanged { session, userId in
            receivedSession = session
            receivedUserId = userId
            expectation.fulfill()
        }

        // When
        let session = Session(key: sessionKey, services: [.chat])
        sut.setSession(session, for: userId)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedSession?.key, sessionKey)
        XCTAssertEqual(receivedUserId, userId)
    }

    func testOnSessionChanged_notifiesMultipleHandlers() {
        // Given
        let expectation1 = expectation(description: "Handler 1 should be called")
        let expectation2 = expectation(description: "Handler 2 should be called")

        sut.onSessionChanged { _, _ in expectation1.fulfill() }
        sut.onSessionChanged { _, _ in expectation2.fulfill() }

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

        sut.onSessionChanged { session, _ in
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
}
