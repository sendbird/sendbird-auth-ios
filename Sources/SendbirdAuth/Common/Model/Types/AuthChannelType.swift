//
//  AuthChannelTypes.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/12.
//

import Foundation

@_spi(SendbirdInternal) public enum AuthChannelType {
    /// Open channel.
    case open
    
    /// Group channel.
    case group
    
    /// Feed channel.
    /// - Since: 4.6.0
    case feed
}

extension AuthChannelType: RawRepresentable, CustomStringConvertible, Codable {
    @_spi(SendbirdInternal) public typealias RawValue = String
    
    @_spi(SendbirdInternal) public var description: String { rawValue }
    
    @_spi(SendbirdInternal) public var rawValue: String {
        switch self {
        case .open: return "open"
        case .group: return "group"
        case .feed: return "feed"
        }
    }
    
    @_spi(SendbirdInternal) public var intValue: Int {
        switch self {
        case .open: return 0
        case .group: return 1
        case .feed: return 2
        }
    }
    
    @_spi(SendbirdInternal) public init(rawValue: String) {
        switch rawValue {
        case "group": self = .group
        case "open": self = .open
        case "feed": self = .feed
        default: self = .group
        }
    }
    
    @_spi(SendbirdInternal) public var urlString: String {
        switch self {
        case .open: return "open_channels"
        case .group, .feed: return "group_channels"
//        case .feed: return "feed_channels" // TODO: 별도의 endpoint가 제공되어야 사용할 수 있음.
        }
    }
    
    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    @_spi(SendbirdInternal) public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        self.init(rawValue: stringValue)
    }
    
    /// Encodes this object.
    ///
    /// - Parameter encoder: `Encoder` instance
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
