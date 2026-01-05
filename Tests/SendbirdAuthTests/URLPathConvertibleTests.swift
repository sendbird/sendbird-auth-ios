import XCTest
@testable import SendbirdAuthSDK
@_spi(SendbirdInternal) import SendbirdAuthSDK

final class URLPathConvertibleTests: XCTestCase {

    // MARK: - URLPath Tests

    func testURLPathFromStringLiteral() {
        let path: URLPath = "users"
        XCTAssertEqual(path.urlPaths, ["users"])
        XCTAssertEqual(path.encodedPath, "/users")
    }

    func testURLPathFromArrayLiteral() {
        let path: URLPath = ["users", "123", "profile"]
        XCTAssertEqual(path.urlPaths, ["users", "123", "profile"])
        XCTAssertEqual(path.encodedPath, "/users/123/profile")
    }

    func testURLPathFromArray() {
        let path = URLPath(array: ["group_channels", "channel_url", "messages"])
        XCTAssertEqual(path.urlPaths, ["group_channels", "channel_url", "messages"])
        XCTAssertEqual(path.encodedPath, "/group_channels/channel_url/messages")
    }

    func testURLPathWithSpecialCharacters() {
        let path: URLPath = ["users", "user@email.com", "profile"]
        XCTAssertEqual(path.encodedPath, "/users/user%40email.com/profile")
    }

    func testURLPathWithSpaces() {
        let path: URLPath = ["channels", "my channel", "messages"]
        // Spaces are encoded as + in URL encoding
        XCTAssertEqual(path.encodedPath, "/channels/my+channel/messages")
    }

    // MARK: - URLPathConvertible Conformance Tests

    func testURLPathConformsToURLPathConvertible() {
        let path: URLPath = ["users", "123"]
        let convertible: any URLPathConvertible = path
        XCTAssertEqual(convertible.urlPath.urlPaths, ["users", "123"])
    }

    func testURLPathsConformsToURLPathConvertible() {
        let urlPaths = URLPaths.users(userId: "test_user")
        let convertible: any URLPathConvertible = urlPaths
        XCTAssertEqual(convertible.urlPath.urlPaths, ["users", "test_user"])
    }

    // MARK: - Custom URLPathConvertible Tests

    func testCustomURLPathConvertible() {
        // Simulating how external modules would define custom endpoints
        enum CustomEndpoints: URLPathConvertible {
            case customFeature(id: String)
            case nestedEndpoint(parentId: String, childId: String)
            case simpleEndpoint

            var urlPath: URLPath {
                switch self {
                case .customFeature(let id):
                    return ["custom", "feature", id]
                case .nestedEndpoint(let parentId, let childId):
                    return ["parent", parentId, "child", childId]
                case .simpleEndpoint:
                    return ["simple", "endpoint"]
                }
            }
        }

        let customPath = CustomEndpoints.customFeature(id: "abc123")
        XCTAssertEqual(customPath.urlPath.urlPaths, ["custom", "feature", "abc123"])
        XCTAssertEqual(customPath.urlPath.encodedPath, "/custom/feature/abc123")

        let nestedPath = CustomEndpoints.nestedEndpoint(parentId: "p1", childId: "c1")
        XCTAssertEqual(nestedPath.urlPath.urlPaths, ["parent", "p1", "child", "c1"])

        let simplePath = CustomEndpoints.simpleEndpoint
        XCTAssertEqual(simplePath.urlPath.encodedPath, "/simple/endpoint")
    }

    func testCustomURLPathConvertibleWithSpecialCharacters() {
        enum SpecialEndpoints: URLPathConvertible {
            case userProfile(email: String)

            var urlPath: URLPath {
                switch self {
                case .userProfile(let email):
                    return ["users", email, "profile"]
                }
            }
        }

        let path = SpecialEndpoints.userProfile(email: "test@example.com")
        XCTAssertEqual(path.urlPath.encodedPath, "/users/test%40example.com/profile")
    }

    // MARK: - URLPaths to URLPath Conversion Tests

    func testURLPathsUsersConversion() {
        let urlPaths = URLPaths.users(userId: "user123")
        let urlPath = urlPaths.urlPath
        XCTAssertEqual(urlPath.urlPaths, ["users", "user123"])
    }

    func testURLPathsGroupChannelsConversion() {
        let urlPaths = URLPaths.groupChannels("channel_url_123")
        let urlPath = urlPaths.urlPath
        XCTAssertEqual(urlPath.urlPaths, ["group_channels", "channel_url_123"])
    }

    func testURLPathsWithNilParameter() {
        let urlPaths = URLPaths.users(userId: nil)
        let urlPath = urlPaths.urlPath
        XCTAssertEqual(urlPath.urlPaths, ["users"])
    }

    func testURLPathsNestedEndpoint() {
        let urlPaths = URLPaths.channelMessages(
            channelType: .group,
            channelURL: "test_channel",
            messageId: 12345
        )
        let urlPath = urlPaths.urlPath
        XCTAssertEqual(urlPath.urlPaths, ["group_channels", "test_channel", "messages", "12345"])
    }

    func testURLPathsSessionKey() {
        let urlPaths = URLPaths.usersSessionKey(userId: "user123")
        let urlPath = urlPaths.urlPath
        XCTAssertEqual(urlPath.urlPaths, ["users", "user123", "session_key"])
    }

    func testURLPathsSdkStatistics() {
        let urlPaths = URLPaths.sdkStatistics
        let urlPath = urlPaths.urlPath
        XCTAssertEqual(urlPath.urlPaths, ["sdk", "statistics"])
    }

    func testURLPathsNotificationStatistics() {
        let urlPaths = URLPaths.notificationStatistics
        let urlPath = urlPaths.urlPath
        XCTAssertEqual(urlPath.urlPaths, ["sdk", "notification_statistics"])
    }

    // MARK: - asPath Property Tests

    func testURLPathAsPath() {
        let path: URLPath = ["api", "v1", "users"]
        XCTAssertEqual(path.asPath, "/api/v1/users")
        XCTAssertEqual(path.asPath, path.encodedPath)
    }
}
