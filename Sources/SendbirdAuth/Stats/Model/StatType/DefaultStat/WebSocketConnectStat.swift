//
//  WebSocketConnectStat.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/12/14.
//

import Foundation

@_spi(SendbirdInternal) public struct WebSocketLatencyInfo {
    var hostURL: String = ""
    var latencyForOpened: Int64 = 0
    var latencyForLOGI: Int64?
    var success: Bool = false
    
    @_spi(SendbirdInternal) public init(
        hostURL: String = "",
        latencyForOpened: Int64 = 0,
        latencyForLOGI: Int64? = nil,
        success: Bool = false
    ) {
        self.hostURL = hostURL
        self.latencyForOpened = latencyForOpened
        self.latencyForLOGI = latencyForLOGI
        self.success = success
    }
}

@_spi(SendbirdInternal) public final class WebSocketConnectStat: DefaultRecordStat {
    @_spi(SendbirdInternal) public enum CodingKeys: String, CodingKey {
        case hostURL = "host_url"
        case latency
        case logiLatency = "logi_latency"
        case success
        case errorCode = "error_code"
        case errorDescription = "error_description"
        case accumulatedTrial = "accum_trial"
        case connectionId = "connection_id"
        case isSoftRateLimited = "is_soft_rate_limited"
    }
    
    @_spi(SendbirdInternal) public let hostURL: String
    @_spi(SendbirdInternal) public let latency: Int64
    @_spi(SendbirdInternal) public let logiLatency: Int64?
    @_spi(SendbirdInternal) public let success: Bool
    @_spi(SendbirdInternal) public let errorCode: Int?
    @_spi(SendbirdInternal) public let errorDescription: String?
    @_spi(SendbirdInternal) public let accumulatedTrial: Int
    @_spi(SendbirdInternal) public let connectionId: String
    @_spi(SendbirdInternal) public let isSoftRateLimited: Bool
    
    @_spi(SendbirdInternal) public init(
        latencyInfo: WebSocketLatencyInfo,
        errorCode: Int?,
        errorDescription: String?,
        timestamp: Int64 = Date().milliSeconds,
        accumulatedTrial: Int,
        connectionId: String,
        isSoftRateLimited: Bool
    ) {
        self.hostURL = latencyInfo.hostURL
        self.latency = latencyInfo.latencyForOpened
        self.logiLatency = latencyInfo.latencyForLOGI
        self.success = latencyInfo.success
        self.errorCode = errorCode
        self.errorDescription = errorDescription
        self.accumulatedTrial = accumulatedTrial
        self.connectionId = connectionId
        self.isSoftRateLimited = isSoftRateLimited
        
        super.init(statType: .webSocketConnect, timestamp: timestamp)
    }
    
    @_spi(SendbirdInternal) public required init(from decoder: Decoder) throws {
        let container = try Self.nestedDecodeContainer(decoder: decoder, keyedBy: CodingKeys.self)
        
        hostURL = try container.decode(String.self, forKey: .hostURL)
        latency = try container.decode(Int64.self, forKey: .latency)
        logiLatency = try container.decodeIfPresent(Int64.self, forKey: .logiLatency)
        success = try container.decode(Bool.self, forKey: .success)
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode)
        errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
        accumulatedTrial = try container.decode(Int.self, forKey: .accumulatedTrial)
        connectionId = try container.decode(String.self, forKey: .connectionId)
        isSoftRateLimited = try container.decode(Bool.self, forKey: .isSoftRateLimited)
        
        try super.init(from: decoder)
    }
    
    @_spi(SendbirdInternal) public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = nestedEncodeContainer(encoder: encoder, keyedBy: CodingKeys.self)
        
        try container.encode(hostURL, forKey: .hostURL)
        try container.encode(latency, forKey: .latency)
        try container.encodeIfPresent(logiLatency, forKey: .logiLatency)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(errorCode, forKey: .errorCode)
        try container.encodeIfPresent(errorDescription, forKey: .errorDescription)
        try container.encode(accumulatedTrial, forKey: .accumulatedTrial)
        try container.encode(connectionId, forKey: .connectionId)
        try container.encode(isSoftRateLimited, forKey: .isSoftRateLimited)
    }
    
    @_spi(SendbirdInternal) public override var description: String {
        """
        WebSocketConnectStat(
            hostURL: \(hostURL),
            latency: \(latency),
            logiLatency: \(String(describing: logiLatency)),
            success: \(success),
            errorCode: \(String(describing: errorCode)),
            errorDescription: \(String(describing: errorDescription)),
            accumulatedTrial: \(accumulatedTrial),
            connectionId: \(connectionId),
            isSoftRateLimited: \(isSoftRateLimited)
        )
        """
    }
}
