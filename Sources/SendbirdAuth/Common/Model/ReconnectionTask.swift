//
//  ReconnectionTask.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 8/16/21.
//

import Foundation

@_spi(SendbirdInternal) public class ReconnectionTask { // ReconnectionParams?
    
    @_spi(SendbirdInternal) public var sessionKey: String
    
    private let baseInterval: Double
    private let maximumInterval: Double
    private let multiplier: Int
    private let maximumRetryCount: Int
    private var backoffPeriod: Double = 0.001
    
    @_spi(SendbirdInternal) public init(config: ReconnectionConfiguration, sessionKey: String) {
        self.baseInterval = config.baseInterval
        self.maximumInterval = config.maximumInterval
        self.multiplier = config.multiplier
        self.maximumRetryCount = config.maximumRetryCount
        self.sessionKey = sessionKey
    }
    
    @_spi(SendbirdInternal) public func shouldRetry(with retryCount: Int) -> Bool {
        Logger.main.debug("retryCount: \(retryCount), enabledEternalRetry: \(enabledEternalRetry), maximumRetryCount: \(maximumRetryCount)")
        if enabledEternalRetry { return true }
        if maximumRetryCount == 0, retryCount == 0 { return true }
        
        return retryCount < maximumRetryCount
    }
    
    @_spi(SendbirdInternal) public var enabledEternalRetry: Bool { maximumRetryCount < 0 }
    
    @_spi(SendbirdInternal) public func backoffPeriod(with retryCount: Int) -> TimeInterval {
        let currentBackoffPeriod = backoffPeriod
        let newBackOff: Double = baseInterval * pow(Double(multiplier), Double(retryCount))
        backoffPeriod = min(newBackOff, maximumInterval)
        return currentBackoffPeriod
    }
}
