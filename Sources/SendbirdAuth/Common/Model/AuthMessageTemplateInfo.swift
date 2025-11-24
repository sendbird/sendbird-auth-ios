//
//  AuthMessageTemplateInfo.swift
//  SendbirdChatSDK
//
//  Created by Damon Park on 2024/02/14.
//

import Foundation

public class AuthMessageTemplateInfo: NSObject, Codable {
    public var templateListToken: String?
    
    public init(
        templateListToken: String
    ) {
        self.templateListToken = templateListToken
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        
        try container.encodeIfPresent(templateListToken, forKey: .templateListToken)
    }
    
    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        self.templateListToken = try container.decodeIfPresent(String.self, forKey: .templateListToken)
    }
}
