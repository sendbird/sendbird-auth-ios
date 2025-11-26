//
//  DailyStatCollector.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 3/6/24.
//

import Foundation

@_spi(SendbirdInternal) public class DailyStatCollector: StatCollectorContract {
    @_spi(SendbirdInternal) public var statConfig: StatConfig
    @_spi(SendbirdInternal) public var enabled: Bool = true
    @_spi(SendbirdInternal) public var storage: DailyRecordStatStorage
    @_spi(SendbirdInternal) public var sentStatCache: [DailyRecordKey] = []
    
    @_spi(SendbirdInternal) public weak var apiClient: StatAPIClientable?
    @_spi(SendbirdInternal) public weak var delegate: StatManagerDelegate?
    
    @_spi(SendbirdInternal) public var isFlushing: Bool = false
    
    @_spi(SendbirdInternal) public var queue = DispatchQueue(
        label: "com.sendbird.stat_collector.daily.\(UUID().uuidString)",
        qos: .background
    )
    @_spi(SendbirdInternal) public var statCacheQueue = DispatchQueue(
        label: "com.sendbird.stat_collector.daily.dedup_cache.\(UUID().uuidString)",
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
        self.storage = DailyRecordStatStorage(userDefaults: userDefaults)
        self.delegate = delegate
        self.enabled = enabled
    }
    
    @_spi(SendbirdInternal) public func appendStat(
        _ stat: DailyRecordStat,
        completion: VoidHandler? = nil
    ) {
        if !self.enabled {
            self.queue.async {
                completion?()
            }
            return
        }

        self.queue.async {
            try? self.storage.upsert(stat: stat)
            
            let isUploadable = self.delegate?.isStatManagerUploadable() ?? false
            
            if isUploadable {
                self.trySendStats(completion: completion)
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
            Logger.stat.debug("DailyStatCollector is flushing stats.")
            self.queue.async {
                completion?()
            }
            return
        }
        
        guard let splittedStats = self.splitStatsByMaxStatCountPerRequest(stats: self.storage.uploadCandidateDailyRecordStats) else {
            self.queue.async {
                completion?()
            }
            return
        }
        
        self.isFlushing = true

        let stats = self.storage.uploadCandidateDailyRecordStats
        
        if stats.count == 0 {
            self.isFlushing = false
            self.queue.async {
                completion?()
            }
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            
            for stats in splittedStats {
                try await RandomStatRequestBalancer.distributeRequest(delayRange: self.statConfig.requestDelayRange)
                
                do {
                    try await self.apiClient?.send(stats: stats)
                    Logger.stat.debug("Sent daily stats.")
                    self.storage.markAsUploaded(stats: stats)
                    self.storage.removeUploadedStats()
                    for stat in stats {
                        self.saveSentStatToCache(stat)
                    }
                    self.delegate?.statManager(self, didSentStats: stats)
                } catch {
                    Logger.external.error("Sending daily stats failure: \(error)")
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
    
    @_spi(SendbirdInternal) public func isSendable(fromAuth: Bool) -> Bool {
        // Not used.
        return true
    }
    
    @_spi(SendbirdInternal) public func splitStatsByMaxStatCountPerRequest(stats: [DailyRecordStat]) -> [[DailyRecordStat]]? {
        if stats.count == 0 || self.statConfig.maxStatCountPerRequest == 0 {
            return nil
        }
        
        let maxStatCountPerRequest = self.statConfig.maxStatCountPerRequest
        return stats.sbd_chunked(into: maxStatCountPerRequest)
    }

    /// Checks if a given `BaseStat` has already been sent by looking it up in the `sentStatDedupCache`.
    /// - Parameter stat: The `BaseStat` instance to check.
    /// - Returns: A Boolean value indicating whether the stat has been sent.
    @_spi(SendbirdInternal) public func lookUpSentStatCache(_ stat: DailyRecordStat) -> Bool {
        self.statCacheQueue.sync {
            self.sentStatCache.contains(stat.key)
        }
    }
    
    /// Saves a `NotificationStat` to the `sentStatDedupCache` to prevent re-sending.
    /// - Parameter stat: The `BaseStat` instance to be saved.
    @_spi(SendbirdInternal) public func saveSentStatToCache(_ stat: DailyRecordStat) {
        self.statCacheQueue.sync {
            self.sentStatCache.append(stat.key)
        }
    }
}
