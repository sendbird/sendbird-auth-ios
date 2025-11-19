//
//  AuthNotificationInfo.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 2/27/23.
//

import Foundation

package class AuthNotificationInfo: NSObject, Codable {
    package var isEnabled: Bool = false

    package var templateListToken: String = ""
    
    package var settingsUpdatedAt: Int64 = 0
    
    package var feedChannels: [String: String] = [:]
    
    package init(
        isEnabled: Bool,
        templateListToken: String,
        settingsUpdatedAt: Int64,
        feedChannels: [String: String]
    ) {
        self.isEnabled = isEnabled
        self.templateListToken = templateListToken
        self.settingsUpdatedAt = settingsUpdatedAt
        self.feedChannels = feedChannels
    }
    
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        
        try container.encodeIfPresent(isEnabled, forKey: .enabled)
        try container.encodeIfPresent(templateListToken, forKey: .templateListToken)
        try container.encodeIfPresent(settingsUpdatedAt, forKey: .settingsUpdatedAt)
        try container.encodeIfPresent(feedChannels, forKey: .feedChannels)
    }
    
    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    package required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.templateListToken = try container.decodeIfPresent(String.self, forKey: .templateListToken) ?? ""
        self.settingsUpdatedAt = try container.decodeIfPresent(Int64.self, forKey: .settingsUpdatedAt) ?? 0
        self.feedChannels = try container.decodeIfPresent([String: String].self, forKey: .feedChannels) ?? [:]
    }
}
