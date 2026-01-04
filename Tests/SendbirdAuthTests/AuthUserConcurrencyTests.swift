//
//  AuthUserConcurrencyTests.swift
//  SendbirdAuthTests
//
//  Created for AA-9763: Fix crash when updating user
//

import XCTest
@testable @_spi(SendbirdInternal) import SendbirdAuthSDK

/// Tests to reproduce concurrency crash in AuthUser.update(with:)
/// Stack trace reference:
/// - AuthUser.nickname.setter + 18 (AuthUser.swift:18)
/// - AuthUser.update(with:) + 157 (AuthUser.swift:157)
final class AuthUserConcurrencyTests: XCTestCase {

    // MARK: - Test: Concurrent nickname read/write

    /// Reproduces crash when reading nickname while another thread is updating it
    /// This simulates the real-world scenario where:
    /// - UI thread reads nickname for cell rendering (collectionView:cellForItemAt:)
    /// - SDK event thread updates user info via AuthUser.update(with:)
    func test_concurrentNicknameAccess_shouldNotCrash() {
        let user = createTestAuthUser(userId: "test_user", nickname: "initial_nickname")

        let iterations = 10000
        let expectation = XCTestExpectation(description: "Concurrent access completed")
        expectation.expectedFulfillmentCount = 2

        // Thread A: Simulates UI thread reading nickname repeatedly
        DispatchQueue.global(qos: .userInteractive).async {
            for _ in 0..<iterations {
                // Simulate reading nickname for UI rendering
                _ = user.nickname
                _ = user.plainProfileImageURL
            }
            expectation.fulfill()
        }

        // Thread B: Simulates SDK event thread updating user
        DispatchQueue.global(qos: .default).async {
            for iteration in 0..<iterations {
                let newUser = self.createTestAuthUser(
                    userId: "test_user",
                    nickname: "updated_nickname_\(iteration)"
                )
                // This calls nickname setter internally
                user.update(with: newUser)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30.0)
    }

    /// More aggressive test with multiple reader threads
    func test_multipleReadersSingleWriter_shouldNotCrash() {
        let user = createTestAuthUser(userId: "test_user", nickname: "initial")

        let iterations = 5000
        let readerCount = 4
        let expectation = XCTestExpectation(description: "Multi-reader test completed")
        expectation.expectedFulfillmentCount = readerCount + 1

        // Multiple reader threads (simulating multiple UI components)
        for _ in 0..<readerCount {
            DispatchQueue.global(qos: .userInteractive).async {
                for _ in 0..<iterations {
                    _ = user.nickname
                    _ = user.plainProfileImageURL
                    _ = user.metaData
                    _ = user.preferredLanguages
                }
                expectation.fulfill()
            }
        }

        // Single writer thread (SDK event handler)
        DispatchQueue.global(qos: .default).async {
            for iteration in 0..<iterations {
                let newUser = self.createTestAuthUser(
                    userId: "test_user",
                    nickname: "nickname_\(iteration)"
                )
                user.update(with: newUser)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 60.0)
    }

    /// Tests concurrent updateUserInfo calls
    func test_concurrentUpdateUserInfo_shouldNotCrash() {
        let user = createTestAuthUser(userId: "test_user", nickname: "initial")

        let iterations = 5000
        let expectation = XCTestExpectation(description: "UpdateUserInfo test completed")
        expectation.expectedFulfillmentCount = 3

        // Reader thread
        DispatchQueue.global(qos: .userInteractive).async {
            for _ in 0..<iterations {
                _ = user.nickname
                _ = user.plainProfileImageURL
            }
            expectation.fulfill()
        }

        // Writer thread 1: update(with:)
        DispatchQueue.global(qos: .default).async {
            for iteration in 0..<iterations {
                let newUser = self.createTestAuthUser(
                    userId: "test_user",
                    nickname: "update_\(iteration)"
                )
                user.update(with: newUser)
            }
            expectation.fulfill()
        }

        // Writer thread 2: updateUserInfo(with:)
        DispatchQueue.global(qos: .utility).async {
            for iteration in 0..<iterations {
                let info: [String: Any] = [
                    "nickname": "info_\(iteration)",
                    "profile_url": "https://example.com/\(iteration).jpg",
                    "require_auth_for_profile_image": iteration % 2 == 0
                ]
                user.updateUserInfo(with: info)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 60.0)
    }

    /// Tests the exact scenario from the crash: reading during update
    func test_readDuringUpdate_exactCrashScenario() {
        let user = createTestAuthUser(userId: "sender_123", nickname: "Sender Name")

        let iterations = 10000
        let expectation = XCTestExpectation(description: "Exact crash scenario completed")
        expectation.expectedFulfillmentCount = 2

        // Simulates: Array<A>.getMessageGroupingPosition -> reads sender.nickname
        DispatchQueue.global(qos: .userInteractive).async {
            for _ in 0..<iterations {
                // Simulating what happens in getMessageGroupingPosition
                _ = user.nickname
                _ = user.userId

                // Simulating cell configuration
                _ = "\(user.nickname): some message"
            }
            expectation.fulfill()
        }

        // Simulates: SDK receives user update event
        DispatchQueue.global(qos: .default).async {
            for iteration in 0..<iterations {
                let updatedUser = self.createTestAuthUser(
                    userId: "sender_123",
                    nickname: "Updated Name \(iteration)"
                )
                user.update(with: updatedUser)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30.0)
    }

    // MARK: - Helper Methods

    private func createTestAuthUser(
        userId: String,
        nickname: String,
        profileURL: String? = nil
    ) -> AuthUser {
        return AuthUser(
            dependency: nil,
            userId: userId,
            nickname: nickname,
            profileURL: profileURL,
            connectionStatus: .online,
            lastSeenAt: 0,
            metaData: [:],
            isActive: true,
            discoveryKey: nil,
            friendName: "",
            prefLangauges: [],
            requireAuth: false,
            isBot: false,
            localUpdatedAt: -1
        )
    }
}
