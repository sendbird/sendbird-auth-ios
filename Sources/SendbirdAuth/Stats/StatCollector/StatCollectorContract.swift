//
//  StatCollectorContract.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 3/6/24.
//

import Foundation

/// A protocol that has interfaces for the stat collector.
/// DefaultStatCollector, NotificationStatCollector, and DailyStatCollector conform this protocol.
/// - Since: 4.18.0
public protocol StatCollectorContract {
    associatedtype RecordStatType: BaseStatType
    
    /// A config that defines when and how the stat collector uploads the appended stat logs.
    /// - Since: 4.18.0
    var statConfig: StatConfig { get set }
    
    var enabled: Bool { get set }
    
    init(
        statConfig: StatConfig,
        apiClient: StatAPIClientable,
        userDefaults: UserDefaults,
        delegate: StatManagerDelegate?,
        enabled: Bool
    )
    
    /// Appends the stat to the storage of the stat collector.
    /// - Parameters:
    ///   - stat: The stat log to be appended
    ///   - completion: The callback to be executed
    func appendStat(
        _ stat: RecordStatType,
        completion: VoidHandler?
    )
    
    /// Uploads the stats that the collector has.
    /// - Parameters:
    ///   - fromAuth: When the collector is `DefaultStatCollector` and the stat manager is enabled and the state of it changes to `.enabled` from `.pending` the value should be `true`. It determines whether the `DefaultStaCollector` will upload the appended stats or not.
    ///   - completion: The callback to be executed
    func trySendStats(
        fromAuth: Bool?,
        completion: VoidHandler?
    )
    
    func removeAll()
}
