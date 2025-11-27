//
//  ConnectionState.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/30/21.
//

import Foundation

@_spi(SendbirdInternal) public typealias ConnectionStateData = SessionData
@_spi(SendbirdInternal) public class SessionData: AuthenticationDataSource, ConnectionStateDataSource {
    // NOTE: applicationId should not reset
    @_spi(SendbirdInternal) public let applicationId: String
    
    @InternalAtomic @_spi(SendbirdInternal) public var baseAppInfo: AuthAppInfo?
    
    @InternalAtomic @_spi(SendbirdInternal) public var currentUser: AuthUser?
    
    @_spi(SendbirdInternal) public var authenticated: Bool { currentUser != nil } // sessionKey != nil &&

    @_spi(SendbirdInternal) public var currentUserId: String { currentUser?.userId ?? "" }
    
    @InternalAtomic @_spi(SendbirdInternal) public var lastConnectedAt: Int64 = 0
    
    @InternalAtomic @_spi(SendbirdInternal) public var firstConnectedAt: Int64 = .max
    
    @InternalAtomic @_spi(SendbirdInternal) public var unreadCountInfo: UnreadCountInfo?
    
    @InternalAtomic @_spi(SendbirdInternal) public var maxUnreadCntOnSuperGroup: Int = 0
    
    @InternalAtomic @_spi(SendbirdInternal) public var reconnectionConfig: ReconnectionConfiguration?
    
    @InternalAtomic @_spi(SendbirdInternal) public private(set) var messageSyncConfig: MessageSyncConfiguration = .default

    // read config
    @InternalAtomic @_spi(SendbirdInternal) public var lastMarkAsReadAllTimestamp: TimeInterval = 0
    
    @InternalAtomic @_spi(SendbirdInternal) public var lastMarkAsDeliveredTimestamp: TimeInterval = 0
    
    @InternalAtomic @_spi(SendbirdInternal) public private(set) var requestDedupIntervalMs: Int64 = LoginEvent.Constants.defaultDedupIntervalMs

    @_spi(SendbirdInternal) public var sessionKey: String?
    
    @_spi(SendbirdInternal) public init(applicationId: String) {
        self.applicationId = applicationId
    }
    
    @_spi(SendbirdInternal) public func clear() {
        self.baseAppInfo = nil
        self.currentUser = nil
        self.lastConnectedAt = 0
        self.firstConnectedAt = .max
        self.unreadCountInfo = nil
        self.maxUnreadCntOnSuperGroup = 0
        self.reconnectionConfig = nil
        self.lastMarkAsDeliveredTimestamp = 0
        self.lastMarkAsReadAllTimestamp = 0
        self.messageSyncConfig = .default
        self.requestDedupIntervalMs = LoginEvent.Constants.defaultDedupIntervalMs
    }
    
    @_spi(SendbirdInternal) public func update(with loginEvent: LoginEvent) {
        baseAppInfo = loginEvent.appInfo
        maxUnreadCntOnSuperGroup = loginEvent.maxUnreadCountOnSuperGroup ?? 1
        reconnectionConfig = loginEvent.reconnectConfiguration
        currentUser = loginEvent.user
        lastConnectedAt = loginEvent.loginTimestamp
        if lastConnectedAt < firstConnectedAt {
            firstConnectedAt = lastConnectedAt
        }
        sessionKey = loginEvent.sessionKey
        if let unreadCountInfo = loginEvent.unreadCountInfo {
            self.update(with: unreadCountInfo)
        }
        self.messageSyncConfig = loginEvent.messageSyncConfiguration
        self.requestDedupIntervalMs = loginEvent.requestDedupIntervalMs
    }
    
    @discardableResult
    @_spi(SendbirdInternal) public func update(with newInfo: UnreadCountInfo) -> Bool {
        if unreadCountInfo == nil {
            unreadCountInfo = newInfo
            return true
        } else if let countInfo = unreadCountInfo, countInfo.timestamp < newInfo.timestamp {
            let (hasChanged, updatedInfo) = countInfo.merge(info: newInfo)
            unreadCountInfo = updatedInfo
            return hasChanged
        }
        
        return false
    }
    
    @_spi(SendbirdInternal) public func update(with sessionKey: String?) {
        self.sessionKey = sessionKey
    }
}

#if TESTCASE
extension SessionData {
    @_spi(SendbirdInternal) public func setRequestDedupIntervalMsForTest(_ interval: Int64) {
        self.requestDedupIntervalMs = interval
    }
}
#endif

