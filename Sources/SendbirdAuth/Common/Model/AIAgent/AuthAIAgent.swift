//
//  AuthAIAgent.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 9/14/21.
//

import Foundation

package class AuthAIAgent {
    /// - Since: 4.26.0
    package class Info: NSObject, Codable {
        package var templateListToken: String?
        
        package init(
            templateListToken: String? = nil
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
}
