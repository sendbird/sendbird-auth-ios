//
//  NotificationStatCollector.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 3/6/24.
//

import Foundation

@_spi(SendbirdInternal) public class NotificationStatCollector: StatCollectorContract {
    @_spi(SendbirdInternal) public var statConfig: StatConfig
    @_spi(SendbirdInternal) public var enabled: Bool = true
    @_spi(SendbirdInternal) public var storage: NotificationRecordStatStorage
    @_spi(SendbirdInternal) public var sentStatDedupCache: [String] = []
    @_spi(SendbirdInternal) public var appendedStatDedupCache: [String] = []
    
    @_spi(SendbirdInternal) public weak var apiClient: StatAPIClientable?
    @_spi(SendbirdInternal) public weak var delegate: StatManagerDelegate?
    
    @_spi(SendbirdInternal) public var isFlushing: Bool = false
    
    @_spi(SendbirdInternal) public var queue = DispatchQueue(
        label: "com.sendbird.stat_collector.notification.\(UUID().uuidString)",
        qos: .background
    )
    @_spi(SendbirdInternal) public var statCacheQueue = DispatchQueue(
        label: "com.sendbird.stat_collector.notification.dedup_cache.\(UUID().uuidString)",
        qos: .background
    )
    
    @_spi(SendbirdInternal) public required init(
        statConfig: StatConfig,
        apiClient: StatAPIClientable,
        userDefaults: UserDefaults,
        delegate: StatManagerDelegate?,
        enabled: Bool = true
    ) {
        self.statConfig = statConfig
        self.apiClient = apiClient
        self.storage = NotificationRecordStatStorage(userDefaults: userDefaults)
        self.delegate = delegate
        self.enabled = enabled
    }
    
    @_spi(SendbirdInternal) public func appendStat(
        _ stat: NotificationStat,
        completion: VoidHandler? = nil
    ) {
        if !self.enabled {
            self.queue.async {
                completion?()
            }
            return
        }
        
        self.queue.async {
            if self.lookUpSentStatCache(stat) {
                completion?()
                return
            }
            
            if self.lookUpAppendedStatCache(stat) {
                completion?()
                return
            }
            
            self.storage.saveStats([stat])
            self.saveAppendedStatToDedupCache(stat)
            
            let isUploadable = self.delegate?.isStatManagerUploadable() ?? false
            
            if isUploadable {
                self.trySendStats(
                    fromAuth: false,
                    completion: completion
                )
            } else {
                completion?()
            }
        }
    }
    
    @_spi(SendbirdInternal) public func trySendStats(
        fromAuth: Bool? = nil,
        completion: VoidHandler? = nil
    ) {
        if !self.enabled {
            self.queue.async {
                completion?()
            }
            return
        }
        
        guard self.isFlushing == false else {
            Logger.stat.debug("NotificationStatCollector is flushing stats.")
            self.queue.async {
                completion?()
            }
            return
        }

        if self.isSendable() == false {
            self.queue.async {
                completion?()
            }
            return
        }
        
        guard let splittedStats = self.splitStatsByMaxStatCountPerRequest(stats: self.storage.loadUnuploadedStats()) else {
            self.queue.async {
                completion?()
            }
            return
        }

        self.isFlushing = true

        Task { [weak self] in
            guard let self = self else { return }
            
            for stats in splittedStats {
                try await RandomStatRequestBalancer.distributeRequest(delayRange: self.statConfig.requestDelayRange)
                
                do {
                    try await self.apiClient?.sendNotificationStats(stats: stats)
                    Logger.stat.debug("Sent notification stats. \(stats.count)")
                    self.storage.saveLastSentAt(Date.now)
                    for stat in stats {
                        stat.isUploaded = true
                        self.saveSentStatToDedupCache(stat)
                    }
                    self.storage.saveStats(stats)
                    self.storage.removeUploadedStats()
                    Logger.stat.debug("Stat count after uploading: \(self.storage.loadStats().count)")
                } catch {
                    Logger.external.error("failure: \(error)")
                    let error = error.asAuthError()
                    
                    if error.errorCode == .statUploadNotAllowed {
                        self.delegate?.statManager(self, newState: .collectOnly)
                    } else {
                        self.delegate?.statManager(self, didFailSendStats: error)
                    }
                }
            }
            
            self.isFlushing = false
            self.queue.async {
                completion?()
            }
        }
    }
    
    @_spi(SendbirdInternal) public func removeAll() {
        self.storage.removeAll()
    }
    
    @_spi(SendbirdInternal) public func isSendable() -> Bool {
        let count = self.storage.loadUnuploadedStats().count
        let minStatCount = self.statConfig.minStatCount
        let lowerThreshold = self.statConfig.lowerThreshold

        Logger.stat.debug("NotificationStat. count: \(count), minStatCount: \(minStatCount), lowerThreshold: \(lowerThreshold)")
        
        if count <= lowerThreshold {
            Logger.stat.debug("NotificationStat. Returned false. count: \(count), lowerThreshold: \(lowerThreshold)")
            return false
        }
        
        let countValid = count >= minStatCount
        let current = Int64(Date().seconds)
        let lastSentAt = Int64(self.storage.loadLastSentAt().seconds)
        
        if !countValid && lastSentAt > 0 {
            let minInterval = self.statConfig.minInterval
            let interval = Int64(current - lastSentAt)
            let result = interval >= minInterval
            
            Logger.stat.debug("NotificationStat. Returned \(result). current: \(current), lastSentAt: \(lastSentAt), minInterval: \(minInterval), interval: \(interval)")
            
            return result
        }
        
        Logger.stat.debug("NotificationStat. Returned \(countValid). lastSentAt: \(lastSentAt)")

        return countValid
    }
    
    @_spi(SendbirdInternal) public func splitStatsByMaxStatCountPerRequest(stats: [NotificationStat]) -> [[NotificationStat]]? {
        if stats.count == 0 || self.statConfig.maxStatCountPerRequest == 0 {
            return nil
        }
        
        let maxStatCountPerRequest = self.statConfig.maxStatCountPerRequest
        return stats.sbd_chunked(into: maxStatCountPerRequest)
    }
    
    /// Checks if a given `BaseStat` has already been appended by looking it up in the `appendedStatDedupCache`.
    /// - Parameter stat: The `BaseStat` instance to check.
    /// - Returns: A Boolean value indicating whether the stat has been appended.
    @_spi(SendbirdInternal) public func lookUpAppendedStatCache(_ stat: NotificationStat) -> Bool {
        self.statCacheQueue.sync {
            return self.appendedStatDedupCache.contains(self.hashNotificationStat( stat))
        }
    }
    
    /// Checks if a given `BaseStat` has already been sent by looking it up in the `sentStatDedupCache`.
    /// - Parameter stat: The `BaseStat` instance to check.
    /// - Returns: A Boolean value indicating whether the stat has been sent.
    @_spi(SendbirdInternal) public func lookUpSentStatCache(_ stat: NotificationStat) -> Bool {
        self.statCacheQueue.sync {
            return self.sentStatDedupCache.contains(self.hashNotificationStat(stat))
        }
    }
    
    /// Appends a `NotificationStat` to the `appendedStats` dictionary.
    /// - Parameter stat: The `BaseStat` instance to be appended.
    @_spi(SendbirdInternal) public func saveAppendedStatToDedupCache(_ stat: NotificationStat) {
        self.statCacheQueue.sync {
            self.appendedStatDedupCache.append(self.hashNotificationStat(stat))
        }
    }
    
    /// Saves a `NotificationStat` to the `sentStatDedupCache` to prevent re-sending.
    /// - Parameter stat: The `BaseStat` instance to be saved.
    @_spi(SendbirdInternal) public func saveSentStatToDedupCache(_ stat: NotificationStat) {
        self.statCacheQueue.sync {
            self.sentStatDedupCache.append(self.hashNotificationStat(stat))
        }
    }
    
    /// Generates a unique hash for a `NotificationStat` object.
    /// - Parameter stat: The `NotificationStat` instance to hash.
    /// - Returns: A `String` representing the unique hash of the notification stat.
    @_spi(SendbirdInternal) public func hashNotificationStat(_ stat: NotificationStat) -> String {
        return "\(stat.action)_\(stat.channelURL)_\(stat.messageId)"
    }
}
