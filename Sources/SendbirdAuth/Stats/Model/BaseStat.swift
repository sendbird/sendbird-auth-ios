//
//  Stat.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/05/30.
//

import Foundation

@_spi(SendbirdInternal) public protocol BaseStatType: Codable, CustomStringConvertible, Hashable, AnyObject {
    var description: String { get }
    var timestamp: Int64 { get }
    var statType: StatType { get }
    var data: [String: AnyCodable]? { get }

    var statId: String? { get set }
    var isUploaded: Bool { get set }

    /// Runtime ID (앱 실행 중 유지되는 고유 ID)
    var runtimeId: String? { get }

    var decoder: JSONDecoder { get }

    func markAsUploaded()
    func copy(with zone: NSZone?) -> Any
}

@_spi(SendbirdInternal) public extension BaseStatType {
    func markAsUploaded() {
        isUploaded = true
    } 

    func copy(with zone: NSZone? = nil) -> Any {
        return makeCodableCopy(decoder: decoder)
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
        try container.encodeIfPresent(runtimeId, forKey: .runtimeId)
        try container.encodeIfPresent(data, forKey: .data)
        try container.encodeIfPresent(statId, forKey: .statId)

        if isUploaded {
            try container.encode(isUploaded, forKey: .isUploaded)
        }
    }

    /// Runtime ID (앱 실행 중 유지되는 고유 ID)
    var runtimeId: String? { nil }
     
    // 공통 디코딩 로직
    // swiftlint:disable large_tuple
    typealias DecodeBasePropertiesResult = (timestamp: Int64, statType: StatType, statId: String?, isUploaded: Bool, data: [String: AnyCodable]?, runtimeId: String?)
    static func decodeBaseProperties(from decoder: Decoder) throws -> DecodeBasePropertiesResult {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)

        let timestamp = try container.decode(Int64.self, forKey: .ts)
        let statType = try container.decode(StatType.self, forKey: .statType)
        let statId = try container.decodeIfPresent(String.self, forKey: .statId)
        let isUploaded = (try? container.decodeIfPresent(Bool.self, forKey: .isUploaded)) ?? false
        let data = try container.decodeIfPresent([String: AnyCodable].self, forKey: .data)
        let runtimeId = try container.decodeIfPresent(String.self, forKey: .runtimeId)

        return (timestamp, statType, statId, isUploaded, data, runtimeId)
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

@_spi(SendbirdInternal) public struct EmptyAdditionalStatData: AdditionalStatDataType {
    
}
@_spi(SendbirdInternal) public protocol AdditionalStatDataType: Codable { }

@_spi(SendbirdInternal) public class BaseStat: BaseStatType {
    // MARK: - Global RuntimeId

    /// 전역 Runtime ID (앱 실행 중 유지되는 고유 ID)
    /// 최초 접근 시 자동 생성되며, 앱 재시작 전까지 유지됩니다.
    @_spi(SendbirdInternal) public private(set) static var globalRuntimeId: String = UUID().uuidString

    // MARK: - Instance Properties

    @_spi(SendbirdInternal) public var description: String { "BaseStat" }

    @_spi(SendbirdInternal) public let timestamp: Int64
    @_spi(SendbirdInternal) public let statType: StatType
    @_spi(SendbirdInternal) public var statId: String?
    @_spi(SendbirdInternal) public var isUploaded: Bool

    /// Runtime ID (앱 실행 중 유지되는 고유 ID)
    /// 명시적으로 설정하지 않으면 globalRuntimeId가 자동 적용됩니다 (해당 statType이 활성화된 경우).
    @_spi(SendbirdInternal) public var runtimeId: String?

    /// This property is only used when generating stats by external request.
    /// When using Stat internally, it is used by inheriting BaseStat, and values ​​under `data` are directly mapped,
    /// so there is no need to save them in the form of a json dictionary.
    @_spi(SendbirdInternal) public let data: [String: AnyCodable]?

    @_spi(SendbirdInternal) public var decoder: JSONDecoder { JSONDecoder() }

    @_spi(SendbirdInternal) public init(
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
        self.runtimeId = nil
    }

    @_spi(SendbirdInternal) public init(
        statType: StatType,
        timestamp: Int64 = Date().milliSeconds,
        statId: String? = nil,
        isUploaded: Bool = false,
        data: [String: AnyCodable]? = nil,
        includeRuntimeId: Bool
    ) {
        self.timestamp = timestamp
        self.statType = statType
        self.statId = statId ?? UUID().uuidString
        self.isUploaded = isUploaded
        self.data = data
        self.runtimeId = includeRuntimeId ? Self.globalRuntimeId : nil
    }
    
    @_spi(SendbirdInternal) public required init(from decoder: Decoder) throws {
        let baseProperties = try Self.decodeBaseProperties(from: decoder)

        self.timestamp = baseProperties.timestamp
        self.statType = baseProperties.statType
        self.statId = baseProperties.statId
        self.isUploaded = baseProperties.isUploaded
        self.data = baseProperties.data
        self.runtimeId = baseProperties.runtimeId
    }
    
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        try encodeBaseProperties(to: encoder)
    }
}
