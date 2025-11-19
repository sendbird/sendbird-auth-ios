//
//  ReconnectionTask.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 8/16/21.
//

import Foundation

package class ReconnectionTask { // ReconnectionParams?
    
    package var sessionKey: String
    
    private let baseInterval: Double
    private let maximumInterval: Double
    private let multiplier: Int
    private let maximumRetryCount: Int
    private var backoffPeriod: Double = 0.001
    
    package init(config: ReconnectionConfiguration, sessionKey: String) {
        self.baseInterval = config.baseInterval
        self.maximumInterval = config.maximumInterval
        self.multiplier = config.multiplier
        self.maximumRetryCount = config.maximumRetryCount
        self.sessionKey = sessionKey
    }
    
    package func shouldRetry(with retryCount: Int) -> Bool {
        Logger.main.debug("retryCount: \(retryCount), enabledEternalRetry: \(enabledEternalRetry), maximumRetryCount: \(maximumRetryCount)")
        if enabledEternalRetry { return true }
        if maximumRetryCount == 0, retryCount == 0 { return true }
        
        return retryCount < maximumRetryCount
    }
    
    package var enabledEternalRetry: Bool { maximumRetryCount < 0 }
    
    package func backoffPeriod(with retryCount: Int) -> TimeInterval {
        let currentBackoffPeriod = backoffPeriod
        let newBackOff: Double = baseInterval * pow(Double(multiplier), Double(retryCount))
        backoffPeriod = min(newBackOff, maximumInterval)
        return currentBackoffPeriod
    }
}
