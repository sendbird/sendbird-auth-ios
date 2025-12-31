import XCTest
@_spi(SendbirdInternal) @testable import SendbirdAuthSDK

final class SendbirdAuthMultipleInstancesTests: XCTestCase {

    // MARK: - Constants

    private let appId = "APP_ID"
    private let anotherAppId = "ANOTHER_APP_ID"
    private let apiHost = "https://api.example.com"
    private let anotherApiHost = "https://another-api.example.com"

    override func tearDown() {
        super.tearDown()
        SendbirdAuth.clearAllInstances()
    }

    // MARK: - create Tests

    func testCreate_alwaysCreatesNewInstance() {
        // Given
        let params = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)

        // When
        let instance1 = SendbirdAuth.create(params: params)
        let instance2 = SendbirdAuth.create(params: params)

        // Then
        XCTAssertFalse(instance1 === instance2, "create should always return new instance")
    }

    func testCreate_registersInstanceToMap() {
        // Given
        let params = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)

        // When
        let created = SendbirdAuth.create(params: params)
        let retrieved = SendbirdAuth.getInstance(appId: appId)

        // Then
        XCTAssertTrue(created === retrieved, "Created instance should be registered to map")
    }

    func testCreate_replacesExistingInstance() {
        // Given
        let params = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        let instance1 = SendbirdAuth.create(params: params)

        // When
        let instance2 = SendbirdAuth.create(params: params)
        let retrieved = SendbirdAuth.getInstance(appId: appId)

        // Then
        XCTAssertFalse(instance1 === instance2)
        XCTAssertTrue(instance2 === retrieved, "New instance should replace old one in map")
    }

    // MARK: - getInstance Tests

    func testGetInstance_existingInstance_returnsInstance() {
        // Given
        let params = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        let created = SendbirdAuth.create(params: params)

        // When
        let retrieved = SendbirdAuth.getInstance(appId: appId)

        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertTrue(created === retrieved)
    }

    func testGetInstance_nonExistingInstance_returnsNil() {
        // When
        let retrieved = SendbirdAuth.getInstance(appId: "NON_EXISTING_APP_ID")

        // Then
        XCTAssertNil(retrieved)
    }

    func testGetInstance_withApiHost_returnsCorrectInstance() {
        // Given
        let params = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        params.customAPIHost = apiHost
        let created = SendbirdAuth.create(params: params)

        // When
        let withHost = SendbirdAuth.getInstance(appId: appId, apiHostUrl: apiHost)
        let withoutHost = SendbirdAuth.getInstance(appId: appId)

        // Then
        XCTAssertNotNil(withHost)
        XCTAssertTrue(created === withHost)
        XCTAssertNil(withoutHost, "Without apiHost should not find instance created with apiHost")
    }

    // MARK: - removeInstance Tests

    func testRemoveInstance_removesFromMap() {
        // Given
        let params = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        _ = SendbirdAuth.create(params: params)
        XCTAssertNotNil(SendbirdAuth.getInstance(appId: appId))

        // When
        SendbirdAuth.removeInstance(appId: appId)

        // Then
        XCTAssertNil(SendbirdAuth.getInstance(appId: appId))
    }

    // MARK: - clearAllInstances Tests

    func testClearAllInstances_removesAllInstances() {
        // Given
        let params1 = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        let params2 = InternalInitParams(applicationId: anotherAppId, isLocalCachingEnabled: false)
        _ = SendbirdAuth.create(params: params1)
        _ = SendbirdAuth.create(params: params2)

        // When
        SendbirdAuth.clearAllInstances()

        // Then
        XCTAssertNil(SendbirdAuth.getInstance(appId: appId))
        XCTAssertNil(SendbirdAuth.getInstance(appId: anotherAppId))
    }

    // MARK: - isInitialized Tests

    func testIsInitialized_withInstance_returnsTrue() {
        // Given
        let params = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        _ = SendbirdAuth.create(params: params)

        // Then
        XCTAssertTrue(SendbirdAuth.isInitialized)
        XCTAssertTrue(SendbirdAuth.isInitialized(appId: appId))
    }

    func testIsInitialized_withoutInstance_returnsFalse() {
        // Then
        XCTAssertFalse(SendbirdAuth.isInitialized)
        XCTAssertFalse(SendbirdAuth.isInitialized(appId: appId))
    }

    // MARK: - instancePref Isolation Tests

    func testInstancePref_isolatedBetweenInstances() {
        // Given
        let params1 = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        params1.customAPIHost = apiHost

        let params2 = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        params2.customAPIHost = anotherApiHost

        // When
        let instance1 = SendbirdAuth.create(params: params1)
        let instance2 = SendbirdAuth.create(params: params2)

        // Then
        let host1: String? = instance1.instancePref.value(forKey: PreferenceKey.customAPIHost)
        let host2: String? = instance2.instancePref.value(forKey: PreferenceKey.customAPIHost)

        XCTAssertEqual(host1, apiHost)
        XCTAssertEqual(host2, anotherApiHost)
        XCTAssertNotEqual(host1, host2, "Each instance should have isolated preferences")
    }
}
