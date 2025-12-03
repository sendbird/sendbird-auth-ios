//
//  DefaultStatCollector.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 3/6/24.
//

import Foundation

@_spi(SendbirdInternal) public class DefaultStatCollector: StatCollectorContract {
    @_spi(SendbirdInternal) public var statConfig: StatConfig
    @_spi(SendbirdInternal) public var enabled: Bool = true
    @_spi(SendbirdInternal) public var storage: DefaultRecordStatStorage
    
    @_spi(SendbirdInternal) public weak var apiClient: StatAPIClientable?
    @_spi(SendbirdInternal) public weak var delegate: StatManagerDelegate?
    
    @_spi(SendbirdInternal) public var isFlushing: Bool = false
    
    @_spi(SendbirdInternal) public var queue = DispatchQueue(
        label: "com.sendbird.stat_collector.default.\(UUID().uuidString)",
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
        self.storage = DefaultRecordStatStorage(userDefaults: userDefaults)
        self.delegate = delegate
        self.enabled = enabled
    }
    
    @_spi(SendbirdInternal) public func appendStat(
        _ stat: DefaultRecordStat,
        completion: VoidHandler? = nil
    ) {
        if !self.enabled {
            self.queue.async {
                completion?()
            }
            return
        }
        
        self.queue.async {
            self.storage.saveStats([stat])
            
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
            Logger.stat.debug("DefaultStatCollector is flushing stats.")
            self.queue.async {
                completion?()
            }
            return
        }
        
        if self.isSendable(fromAuth: fromAuth ?? false) == false {
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
        
        self.isFlushing = false
        
        Task { [weak self] in
            guard let self = self else { return }
            
            for stats in splittedStats {
                try await RandomStatRequestBalancer.distributeRequest(delayRange: self.statConfig.requestDelayRange)
                
                do {
                    try await self.apiClient?.send(stats: stats)
                    Logger.stat.debug("Sent default stats. \(stats.count)")
                    self.storage.saveLastSentAt(Date.now)
                    for stat in stats {
                        stat.isUploaded = true
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
    
    @_spi(SendbirdInternal) public func isSendable(fromAuth: Bool) -> Bool {
        let count = self.storage.loadUnuploadedStats().count
        let lowerThreshold = self.statConfig.lowerThreshold
        
        if count < lowerThreshold {
            Logger.stat.debug("DefaultStat. Returned false. count: \(count), lowerThreshold: \(lowerThreshold)")
            return false
        }
        
        if fromAuth {
            let minStatCount = self.statConfig.minStatCount
            let result = minStatCount >= 0 && (count == minStatCount || (count % self.statConfig.modStatCount) == 0)
            
            Logger.stat.debug("DefaultStat. Returned \(result). fromAuth: \(fromAuth), count: \(count), minStatCount: \(minStatCount), modStatCount: \(self.statConfig.modStatCount)")
            
            return result
        } else {
            let current = Int64(Date().seconds)
            let lastSentAt = Int64(self.storage.loadLastSentAt().seconds)
            let minInterval = self.statConfig.minInterval
            let interval = current - lastSentAt
            let result = interval > minInterval
            
            Logger.stat.debug("DefaultStat. Returned \(result). current: \(current), lastSentAt: \(lastSentAt), minInterval: \(minInterval), interval: \(interval)")
            
            return result
        }
    }
    
    @_spi(SendbirdInternal) public func splitStatsByMaxStatCountPerRequest(stats: [DefaultRecordStat]) -> [[DefaultRecordStat]]? {
        if stats.count == 0 || self.statConfig.maxStatCountPerRequest == 0 {
            return nil
        }
        
        let maxStatCountPerRequest = self.statConfig.maxStatCountPerRequest
        return stats.sbd_chunked(into: maxStatCountPerRequest)
    }
}
