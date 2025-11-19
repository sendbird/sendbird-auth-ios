//
//  StatAPIClient.swift
//  SendbirdChatTests
//
//  Created by Ernest Hong on 2022/06/02.
//

import Foundation

package class StatAPIClient: StatAPIClientable {
    private weak var requestQueue: RequestQueue?
    package var deviceId: String = ""

    #if TESTCASE
        // For test
        package var mockEnabled: Bool?
        package var mockError: AuthError?
    #endif

    package init(requestQueue: RequestQueue) {
        self.requestQueue = requestQueue
    }

    // NotificationStat을 제외한 나머지 Stat log만 전송
    package func send<RecordStatType>(
        stats: [RecordStatType]
    ) async throws where RecordStatType: BaseStatType {
        guard let requestQueue else {
            throw AuthClientError.invalidInitialization.asAuthError(message: "Request queue is not initialized.")
        }

        var copiedStats: [RecordStatType] = []
        for stat in stats {
            let copiedStat = stat.makeCodableCopy(decoder: SendbirdAuth.authDecoder)
            Logger.stat.debug("\(String(describing: stat.description))")
            copiedStat.statId = nil
            copiedStats.append(copiedStat)
        }

        #if TESTCASE
        if let mockEnabled, mockEnabled == true {
            Logger.stat.debug("StatAPIClient mock enabled.")
            if let mockError = mockError {
                throw mockError
            } else {
                return
            }
        }
        #endif
        
        return try await withCheckedThrowingContinuation { continuation in
            requestQueue.post(
                path: .sdkStatistics,
                body: [
                    .logEntries: copiedStats,
                    .deviceId: deviceId,
                ]
            ) { (res: Result<DefaultResponse, AuthError>) in
                switch res {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // NotificationStat만 전송
    package func sendNotificationStats(stats: [NotificationStat]) async throws {
        guard let requestQueue else {
            throw AuthClientError.invalidInitialization.asAuthError(message: "Request queue is not initialized.")
        }

        var copiedStats: [NotificationStat] = []
        for stat in stats {
            let copiedStat = stat.makeCodableCopy(decoder: SendbirdAuth.authDecoder)
            Logger.stat.debug("\(String(describing: stat.description))")
            copiedStat.statId = nil
            copiedStats.append(copiedStat)
        }

        #if TESTCASE
        if mockEnabled == true {
            Logger.stat.debug(#function, "StatAPIClient mock enabled.")
            if let mockError = mockError {
                throw mockError
            } else {
                return
            }
        }
        #endif

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            requestQueue.post(
                path: .notificationStatistics,
                body: [
                    .logEntries: copiedStats,
                    .deviceId: deviceId
                ]
            ) { (res: Result<DefaultResponse, AuthError>) in
                switch res {
                case .success:
                    continuation.resume()
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    package func setDeviceId(deviceId: String) {
        self.deviceId = deviceId
    }

    #if TESTCASE
    package func setMockResult(enabled: Bool, error: AuthError?) {
        mockEnabled = enabled
        mockError = error
    }
    #endif
}
