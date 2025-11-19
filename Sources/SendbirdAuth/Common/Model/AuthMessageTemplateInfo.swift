//
//  AuthMessageTemplateInfo.swift
//  SendbirdChatSDK
//
//  Created by Damon Park on 2024/02/14.
//

import Foundation

package class AuthMessageTemplateInfo: NSObject, Codable {
    package var templateListToken: String?
    
    package init(
        templateListToken: String
    ) {
        self.templateListToken = templateListToken
    }
    
    package func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        
        try container.encodeIfPresent(templateListToken, forKey: .templateListToken)
    }
    
    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    package required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        self.templateListToken = try container.decodeIfPresent(String.self, forKey: .templateListToken)
    }
}
