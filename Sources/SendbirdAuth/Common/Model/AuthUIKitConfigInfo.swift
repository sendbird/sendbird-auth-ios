//
//  AuthUIKitConfigInfo.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 5/10/23.
//

import Foundation

package final class AuthUIKitConfigInfo: Codable {
    package var lastUpdatedAt: Int64 = 0
    
    package init() {
        
    }
    
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        
        try container.encodeIfPresent(lastUpdatedAt, forKey: .lastUpdatedAt)
    }
    
    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    package required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        self.lastUpdatedAt = try container.decodeIfPresent(Int64.self, forKey: .lastUpdatedAt) ?? 0
    }
}
