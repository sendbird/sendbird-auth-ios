//
//  AuthUIKitConfigInfo.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 5/10/23.
//

import Foundation

public final class AuthUIKitConfigInfo: Codable {
    public var lastUpdatedAt: Int64 = 0
    
    public init() {
        
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        
        try container.encodeIfPresent(lastUpdatedAt, forKey: .lastUpdatedAt)
    }
    
    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        self.lastUpdatedAt = try container.decodeIfPresent(Int64.self, forKey: .lastUpdatedAt) ?? 0
    }
}
