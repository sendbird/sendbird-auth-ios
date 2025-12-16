//
//  StatAPIClient.swift
//  SendbirdChatTests
//
//  Created by Ernest Hong on 2022/06/02.
//

import Foundation

@_spi(SendbirdInternal) public class StatAPIClient: StatAPIClientable {
    private weak var requestQueue: RequestQueue?
    @_spi(SendbirdInternal) public var deviceId: String = ""

#if DEBUG
    // For test
    @_spi(SendbirdInternal) public var mockEnabled: Bool?
    @_spi(SendbirdInternal) public var mockError: AuthError?
#endif

    @_spi(SendbirdInternal) public init(requestQueue: RequestQueue) {
        self.requestQueue = requestQueue
    }

    // NotificationStat을 제외한 나머지 Stat log만 전송
    @_spi(SendbirdInternal) public func send<RecordStatType>(
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

    #if DEBUG
        if let mockEnabled, mockEnabled == true {
            Logger.stat.debug("StatAPIClient mock enabled.")
            if let mockError = mockError {
                throw mockError
            } else {
                return
            }
        }
    #endif

        return try await withSafeThrowingContinuation { continuation in
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
    @_spi(SendbirdInternal) public func sendNotificationStats(stats: [NotificationStat]) async throws {
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

    #if DEBUG
        if mockEnabled == true {
            Logger.stat.debug(#function, "StatAPIClient mock enabled.")
            if let mockError = mockError {
                throw mockError
            } else {
                return
            }
        }
    #endif

        try await withSafeThrowingContinuation { continuation in
            requestQueue.post(
                path: .notificationStatistics,
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

    @_spi(SendbirdInternal) public func setDeviceId(deviceId: String) {
        self.deviceId = deviceId
    }

#if DEBUG
    @_spi(SendbirdInternal) public func setMockResult(enabled: Bool, error: AuthError?) {
        mockEnabled = enabled
        mockError = error
    }
#endif
}
