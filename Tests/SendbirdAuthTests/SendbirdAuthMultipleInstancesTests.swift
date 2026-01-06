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

    // MARK: - getOrCreate Tests

    func testGetOrCreate_sameParams_returnsSameInstance() {
        // Given
        let params = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)

        // When
        let instance1 = SendbirdAuth.getOrCreate(params: params)
        let instance2 = SendbirdAuth.getOrCreate(params: params)

        // Then
        XCTAssertTrue(instance1 === instance2, "Same params should return same instance")
    }

    func testGetOrCreate_differentAppId_returnsDifferentInstance() {
        // Given
        let params1 = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        let params2 = InternalInitParams(applicationId: anotherAppId, isLocalCachingEnabled: false)

        // When
        let instance1 = SendbirdAuth.getOrCreate(params: params1)
        let instance2 = SendbirdAuth.getOrCreate(params: params2)

        // Then
        XCTAssertFalse(instance1 === instance2, "Different appId should return different instances")
    }

    func testGetOrCreate_sameAppIdDifferentApiHost_returnsDifferentInstance() {
        // Given
        let params1 = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        params1.customAPIHost = apiHost

        let params2 = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        params2.customAPIHost = anotherApiHost

        // When
        let instance1 = SendbirdAuth.getOrCreate(params: params1)
        let instance2 = SendbirdAuth.getOrCreate(params: params2)

        // Then
        XCTAssertFalse(instance1 === instance2, "Same appId with different apiHost should return different instances")
    }

    // MARK: - getInstance Tests

    func testGetInstance_existingInstance_returnsInstance() {
        // Given
        let params = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        let created = SendbirdAuth.getOrCreate(params: params)

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
        let created = SendbirdAuth.getOrCreate(params: params)

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
        _ = SendbirdAuth.getOrCreate(params: params)
        XCTAssertNotNil(SendbirdAuth.getInstance(appId: appId))

        // When
        SendbirdAuth.removeInstance(appId: appId)

        // Then
        XCTAssertNil(SendbirdAuth.getInstance(appId: appId))
    }
    
    func testRemoveInstance_withSelfInstance() {
        // Given
        let params = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        let instance = SendbirdAuth.getOrCreate(params: params)
        XCTAssertNotNil(SendbirdAuth.getInstance(appId: appId))
        
        // When
        SendbirdAuth.removeInstance(instance)
        
        // Then
        XCTAssertNil(SendbirdAuth.getInstance(appId: appId))
    }        

    // MARK: - clearAllInstances Tests

    func testClearAllInstances_removesAllInstances() {
        // Given
        let params1 = InternalInitParams(applicationId: appId, isLocalCachingEnabled: false)
        let params2 = InternalInitParams(applicationId: anotherAppId, isLocalCachingEnabled: false)
        _ = SendbirdAuth.getOrCreate(params: params1)
        _ = SendbirdAuth.getOrCreate(params: params2)

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
        _ = SendbirdAuth.getOrCreate(params: params)

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
        let instance1 = SendbirdAuth.getOrCreate(params: params1)
        let instance2 = SendbirdAuth.getOrCreate(params: params2)

        // Then
        let host1: String? = instance1.instancePref.value(forKey: PreferenceKey.customAPIHost)
        let host2: String? = instance2.instancePref.value(forKey: PreferenceKey.customAPIHost)

        XCTAssertEqual(host1, apiHost)
        XCTAssertEqual(host2, anotherApiHost)
        XCTAssertNotEqual(host1, host2, "Each instance should have isolated preferences")
    }
}
