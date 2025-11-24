//
//  ConnectionState.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/30/21.
//

import Foundation

public typealias ConnectionStateData = SessionData
public class SessionData: AuthenticationDataSource, ConnectionStateDataSource {
    // NOTE: applicationId should not reset
    public let applicationId: String
    
    @InternalAtomic public var baseAppInfo: AuthAppInfo?
    
    @InternalAtomic public var currentUser: AuthUser?
    
    public var authenticated: Bool { currentUser != nil } // sessionKey != nil &&

    public var currentUserId: String { currentUser?.userId ?? "" }
    
    @InternalAtomic public var lastConnectedAt: Int64 = 0
    
    @InternalAtomic public var firstConnectedAt: Int64 = .max
    
    @InternalAtomic public var unreadCountInfo: UnreadCountInfo?
    
    @InternalAtomic public var maxUnreadCntOnSuperGroup: Int = 0
    
    @InternalAtomic public var reconnectionConfig: ReconnectionConfiguration?
    
    @InternalAtomic public private(set) var messageSyncConfig: MessageSyncConfiguration = .default

    // read config
    @InternalAtomic public var lastMarkAsReadAllTimestamp: TimeInterval = 0
    
    @InternalAtomic public var lastMarkAsDeliveredTimestamp: TimeInterval = 0
    
    @InternalAtomic public private(set) var requestDedupIntervalMs: Int64 = LoginEvent.Constants.defaultDedupIntervalMs

    public var sessionKey: String?
    
    public init(applicationId: String) {
        self.applicationId = applicationId
    }
    
    public func clear() {
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
    
    public func update(with loginEvent: LoginEvent) {
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
    public func update(with newInfo: UnreadCountInfo) -> Bool {
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
    
    public func update(with sessionKey: String?) {
        self.sessionKey = sessionKey
    }
}

#if TESTCASE
extension SessionData {
    public func setRequestDedupIntervalMsForTest(_ interval: Int64) {
        self.requestDedupIntervalMs = interval
    }
}
#endif

