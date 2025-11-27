//
//  APIResultStat.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/12/14.
//

import Foundation

final class APIResultStat: DefaultRecordStat {
    
    enum CodingKeys: String, CodingKey {
        case endpoint
        case method
        case latency
        case success
        case errorCode = "error_code"
        case errorDescription = "error_description"
    }
    
    let endpoint: String
    let method: String
    let latency: Int64
    let success: Bool
    let errorCode: Int?
    let errorDescription: String?
    
    init(
        endpoint: String,
        method: String,
        latency: Int64,
        success: Bool,
        errorCode: Int?,
        errorDescription: String?,
        timestamp: Int64 = Date().milliSeconds
    ) {
        self.endpoint = endpoint
        self.method = method
        self.latency = latency
        self.success = success
        self.errorCode = errorCode
        self.errorDescription = errorDescription
        
        super.init(statType: .apiResult, timestamp: timestamp)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try Self.nestedDecodeContainer(decoder: decoder, keyedBy: CodingKeys.self)
        
        endpoint = try container.decode(String.self, forKey: .endpoint)
        method = try container.decode(String.self, forKey: .method)
        latency = try container.decode(Int64.self, forKey: .latency)
        success = try container.decode(Bool.self, forKey: .success)
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode)
        errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
        
        try super.init(from: decoder)
    }
    
    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = nestedEncodeContainer(encoder: encoder, keyedBy: CodingKeys.self)
        
        try container.encode(endpoint, forKey: .endpoint)
        try container.encode(method, forKey: .method)
        try container.encode(latency, forKey: .latency)
        try container.encode(success, forKey: .success)
        try container.encodeIfPresent(errorCode, forKey: .errorCode)
        try container.encodeIfPresent(errorDescription, forKey: .errorDescription)
    }
    
    override var description: String {
        """
        APIResultStat(
            endpoint: \(endpoint),
            method: \(method),
            latency: \(latency),
            success: \(success),
            errorCode: \(String(describing: errorCode)),
            errorDescription: \(String(describing: errorDescription))
        )
        """
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return makeCodableCopy(decoder: SendbirdAuth.authDecoder)
    }
}
