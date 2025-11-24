//
//  Stat.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/05/30.
//

import Foundation

public protocol BaseStatType: Codable, CustomStringConvertible, Hashable, AnyObject {
    var description: String { get }
    var timestamp: Int64 { get }
    var statType: StatType { get }
    var data: [String: AnyCodable]? { get }
    
    var statId: String? { get set }
    var isUploaded: Bool { get set }
    
    func markAsUploaded()
    func copy(with zone: NSZone?) -> Any
}

public extension BaseStatType {
    func markAsUploaded() {
        isUploaded = true
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return makeCodableCopy(decoder: SendbirdAuth.authDecoder)
    }
    
    func nestedEncodeContainer<NestedKey>(
        encoder: Encoder,
        keyedBy nestedCodingKey: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        
        return container
            .superEncoder(forKey: .data)
            .container(keyedBy: nestedCodingKey)
    }
    
    static func nestedDecodeContainer<NestedKey>(
        decoder: Decoder,
        keyedBy nestedCodingKey: NestedKey.Type
    ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        return try container.nestedContainer(keyedBy: nestedCodingKey, forKey: .data)
    }
    
    // 공통 인코딩 로직
    func encodeBaseProperties(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        
        try container.encode(timestamp, forKey: .ts)
        try container.encode(statType, forKey: .statType)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(statId, forKey: .statId)
        
        if isUploaded {
            try container.encode(isUploaded, forKey: .isUploaded)
        }
    }
     
    // 공통 디코딩 로직
    // swiftlint:disable large_tuple
    typealias DecodeBasePropertiesResult = (timestamp: Int64, statType: StatType, statId: String?, isUploaded: Bool, data: [String: AnyCodable]?)
    static func decodeBaseProperties(from decoder: Decoder) throws -> DecodeBasePropertiesResult {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        let timestamp = try container.decode(Int64.self, forKey: .ts)
        let statType = try container.decode(StatType.self, forKey: .statType)
        let statId = try container.decodeIfPresent(String.self, forKey: .statId)
        let isUploaded = (try? container.decodeIfPresent(Bool.self, forKey: .isUploaded)) ?? false
        let data = try container.decodeIfPresent([String: AnyCodable].self, forKey: .data)
        
        return (timestamp, statType, statId, isUploaded, data)
    }
    // swiftlint:enable large_tuple
    
    // Equatable
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.statId == rhs.statId &&
        lhs.timestamp == rhs.timestamp &&
        lhs.statType == rhs.statType &&
        lhs.isUploaded == rhs.isUploaded &&
        lhs.data == rhs.data
    }
    
    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(statId)
        hasher.combine(timestamp)
        hasher.combine(statType)
        hasher.combine(isUploaded)
        hasher.combine(data)
    }
}

public struct EmptyAdditionalStatData: AdditionalStatDataType {
    
}
public protocol AdditionalStatDataType: Codable { }

public class BaseStat: BaseStatType {
    public var description: String { "BaseStat" }
    
    public let timestamp: Int64
    public let statType: StatType
    public var statId: String?
    public var isUploaded: Bool

    /// This property is only used when generating stats by external request.
    /// When using Stat internally, it is used by inheriting BaseStat, and values ​​under `data` are directly mapped,
    /// so there is no need to save them in the form of a json dictionary.
    public let data: [String: AnyCodable]?
    
    public init(
        statType: StatType,
        timestamp: Int64 = Date().milliSeconds,
        statId: String? = nil,
        isUploaded: Bool = false,
        data: [String: AnyCodable]? = nil
    ) {
        self.timestamp = timestamp
        self.statType = statType
        self.statId = statId ?? UUID().uuidString
        self.isUploaded = isUploaded
        
        self.data = data
    }
    
    public required init(from decoder: Decoder) throws {
        let baseProperties = try Self.decodeBaseProperties(from: decoder)
        
        self.timestamp = baseProperties.timestamp
        self.statType = baseProperties.statType
        self.statId = baseProperties.statId
        self.isUploaded = baseProperties.isUploaded
        
        self.data = baseProperties.data
    }
    
    public func encode(to encoder: Encoder) throws {
        try encodeBaseProperties(to: encoder)
    }
}
