@testable import SendbirdAuthSDK
import XCTest
@_spi(SendbirdInternal) import SendbirdAuthSDK

final class URLPathConvertibleTests: XCTestCase {
    // MARK: - URLPathConvertible Conformance Tests

    func testURLPathConformsToURLPathConvertible() {
        let path: URLPath = ["users", "123"]
        let convertible: any URLPathConvertible = path
        XCTAssertEqual(convertible.urlPath.urlPaths, ["users", "123"])
    }

    func testURLPathsConformsToURLPathConvertible() {
        let urlPaths = URLPaths.usersSessionKey(userId: "test_user") // Any `URLPath`'s case
        let convertible: any URLPathConvertible = urlPaths
        XCTAssertEqual(convertible.urlPath.urlPaths, ["users", "test_user", "session_key"])
    }

    // MARK: - Custom URLPathConvertible Tests

    func testCustomURLPathConvertible() {
        // Simulating how external modules would define custom endpoints
        enum CustomEndpoints: URLPathConvertible {
            case customFeature(id: String)

            var urlPath: URLPath {
                switch self {
                case let .customFeature(id):
                    return ["custom", "feature", id]
                }
            }
        }

        let customPath = CustomEndpoints.customFeature(id: "abc123")
        XCTAssertEqual(customPath.urlPath.urlPaths, ["custom", "feature", "abc123"])
    }
}
