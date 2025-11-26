//
//  AuthUIKitConfigInfo.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 5/10/23.
//

import Foundation

@_spi(SendbirdInternal) public final class AuthUIKitConfigInfo: Codable {
    @_spi(SendbirdInternal) public var lastUpdatedAt: Int64 = 0
    
    @_spi(SendbirdInternal) public init() {
        
    }
    
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        
        try container.encodeIfPresent(lastUpdatedAt, forKey: .lastUpdatedAt)
    }
    
    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    @_spi(SendbirdInternal) public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        self.lastUpdatedAt = try container.decodeIfPresent(Int64.self, forKey: .lastUpdatedAt) ?? 0
    }
}
