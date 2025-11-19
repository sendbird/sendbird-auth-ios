//
//  ConnectionState.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/30/21.
//

import Foundation

package typealias ConnectionStateData = SessionData
package class SessionData: AuthenticationDataSource, ConnectionStateDataSource {
    // NOTE: applicationId should not reset
    package let applicationId: String
    
    @InternalAtomic package var baseAppInfo: AuthAppInfo?
    
    @InternalAtomic package var currentUser: AuthUser?
    
    package var authenticated: Bool { currentUser != nil } // sessionKey != nil &&

    package var currentUserId: String { currentUser?.userId ?? "" }
    
    @InternalAtomic package var lastConnectedAt: Int64 = 0
    
    @InternalAtomic package var firstConnectedAt: Int64 = .max
    
    @InternalAtomic package var unreadCountInfo: UnreadCountInfo?
    
    @InternalAtomic package var maxUnreadCntOnSuperGroup: Int = 0
    
    @InternalAtomic package var reconnectionConfig: ReconnectionConfiguration?
    
    @InternalAtomic package private(set) var messageSyncConfig: MessageSyncConfiguration = .default

    // read config
    @InternalAtomic package var lastMarkAsReadAllTimestamp: TimeInterval = 0
    
    @InternalAtomic package var lastMarkAsDeliveredTimestamp: TimeInterval = 0
    
    @InternalAtomic package private(set) var requestDedupIntervalMs: Int64 = LoginEvent.Constants.defaultDedupIntervalMs

    package var sessionKey: String?
    
    package init(applicationId: String) {
        self.applicationId = applicationId
    }
    
    package func clear() {
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
    
    package func update(with loginEvent: LoginEvent) {
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
    package func update(with newInfo: UnreadCountInfo) -> Bool {
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
    
    package func update(with sessionKey: String?) {
        self.sessionKey = sessionKey
    }
}

#if TESTCASE
extension SessionData {
    package func setRequestDedupIntervalMsForTest(_ interval: Int64) {
        self.requestDedupIntervalMs = interval
    }
}
#endif

