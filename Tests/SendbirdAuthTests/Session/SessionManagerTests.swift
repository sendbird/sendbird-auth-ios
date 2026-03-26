import XCTest
@_spi(SendbirdInternal) @testable import SendbirdAuthSDK

final class SessionManagerTests: XCTestCase {

    private let appId = "test-app"
    private let userId = "testUser"
    private let sessionKey = "test-session-key"

    private var sut: SessionManager!

    override func setUp() {
        super.setUp()
        Session.clearUserDefaults()
        sut = SessionManager(applicationId: appId, userId: userId)
    }

    override func tearDown() {
        Session.clearUserDefaults()
        sut = nil
        super.tearDown()
    }

    func testInitialState_sessionIsNil() {
        XCTAssertNil(sut.loadSession())
        XCTAssertEqual(sut.userId, userId)
    }

    func testSetSession_storesSessionAndNotifiesObserver() {
        let session = Session(key: sessionKey, services: [.chat])
        let observer = MockSessionObserver()
        let expectation = expectation(description: "Session should be set")
        observer.onSessionChange = { received in
            XCTAssertEqual(received?.key, session.key)
            expectation.fulfill()
        }
        sut.addSessionObserver(observer)

        sut.setSession(session)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(sut.loadSession()?.key, sessionKey)
    }

    func testSetSession_withNil_clearsSessionAndNotifiesObserver() {
        let session = Session(key: sessionKey, services: [.chat])
        let observer = MockSessionObserver()
        let setExpectation = expectation(description: "Session should be set")
        let clearExpectation = expectation(description: "Session should be cleared")
        var callCount = 0

        observer.onSessionChange = { received in
            callCount += 1
            if callCount == 1 {
                XCTAssertEqual(received?.key, session.key)
                setExpectation.fulfill()
            } else {
                XCTAssertNil(received)
                clearExpectation.fulfill()
            }
        }
        sut.addSessionObserver(observer)

        sut.setSession(session)
        wait(for: [setExpectation], timeout: 1.0)

        sut.setSession(nil)

        wait(for: [clearExpectation], timeout: 1.0)
        XCTAssertNil(sut.loadSession())
    }

    func testLoadSession_restoresPersistedSessionAcrossInstances() {
        let session = Session(key: sessionKey, services: [.chat, .feed])
        sut.setSession(session)

        let anotherManager = SessionManager(applicationId: appId, userId: userId)

        XCTAssertEqual(anotherManager.loadSession()?.key, sessionKey)
    }

    func testLoadSession_forDifferentUser_returnsNil() {
        sut.setSession(Session(key: sessionKey, services: [.chat]))

        let anotherManager = SessionManager(applicationId: appId, userId: "differentUser")

        XCTAssertNil(anotherManager.loadSession())
    }

    func testSubmitRefreshedSession_rejectsRollbackKey() {
        let current = Session(key: "v1", services: [.chat])
        sut.setSession(current)

        XCTAssertFalse(sut.submitRefreshedSession(current))
        XCTAssertEqual(sut.loadSession()?.key, "v1")
    }

    func testSubmitRefreshedSession_acceptsNewKeyAndNotifiesObserver() {
        sut.setSession(Session(key: "v1", services: [.chat]))
        let expectation = expectation(description: "Observer should receive refreshed session")
        let observer = MockSessionObserver()
        observer.onSessionChange = { session in
            if session?.key == "v2" {
                expectation.fulfill()
            }
        }
        sut.addSessionObserver(observer)

        let accepted = sut.submitRefreshedSession(Session(key: "v2", services: [.chat]))

        XCTAssertTrue(accepted)
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(sut.loadSession()?.key, "v2")
    }

    func testHasRefreshedSession_whenStoredSessionDiffers_returnsTrue() {
        sut.setSession(Session(key: "v2", services: [.chat]))

        XCTAssertTrue(sut.hasRefreshedSession(current: Session(key: "v1", services: [.chat])))
        XCTAssertFalse(sut.hasRefreshedSession(current: Session(key: "v2", services: [.chat])))
    }

    func testRequestSessionRefresh_notifiesOnlyRefreshableObservers() {
        let refreshable = MockSessionObserver()
        refreshable.canRefreshSessionOverride = true
        let waiting = MockSessionObserver()
        waiting.canRefreshSessionOverride = false

        let expectation = expectation(description: "Refreshable observer should receive request")
        refreshable.onSessionRefreshRequested = { session in
            XCTAssertEqual(session.key, "v1")
            expectation.fulfill()
        }
        waiting.onSessionRefreshRequested = { _ in
            XCTFail("Non-refreshable observer should not receive refresh request")
        }

        sut.addSessionObserver(refreshable)
        sut.addSessionObserver(waiting)

        let accepted = sut.requestSessionRefresh(for: Session(key: "v1", services: [.chat]))

        XCTAssertTrue(accepted)
        wait(for: [expectation], timeout: 1.0)
    }

    func testNotifySessionRefreshFailed_notifiesObservers() {
        let observer = MockSessionObserver()
        let expectation = expectation(description: "Observer should receive failure")
        observer.onSessionRefreshFailed = {
            expectation.fulfill()
        }
        sut.addSessionObserver(observer)

        sut.notifySessionRefreshFailed()

        wait(for: [expectation], timeout: 1.0)
    }

    func testRegistry_returnsSharedManagerForSameKey() {
        let registry = DefaultSessionManagerRegistry()

        let first = registry.sessionManager(applicationId: appId, userId: userId)
        let second = registry.sessionManager(applicationId: appId, userId: userId)

        XCTAssertTrue(first === second)
    }

    func testRegistry_returnsDifferentManagersForDifferentUsers() {
        let registry = DefaultSessionManagerRegistry()

        let first = registry.sessionManager(applicationId: appId, userId: userId)
        let second = registry.sessionManager(applicationId: appId, userId: "other-user")

        XCTAssertFalse(first === second)
    }
}

private final class MockSessionObserver: SessionObserver {
    var canRefreshSessionOverride = true
    var onSessionChange: ((Session?) -> Void)?
    var onSessionRefreshRequested: ((Session) -> Void)?
    var onSessionRefreshFailed: (() -> Void)?

    var canRefreshSession: Bool { canRefreshSessionOverride }

    func sessionDidChange(_ session: Session?) {
        onSessionChange?(session)
    }

    func sessionRefreshRequested(for session: Session) {
        onSessionRefreshRequested?(session)
    }

    func sessionRefreshFailed() {
        onSessionRefreshFailed?()
    }
}
