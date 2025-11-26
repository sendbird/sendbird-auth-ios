//
//  AuthAIAgent.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 9/14/21.
//

import Foundation

@_spi(SendbirdInternal) public class AuthAIAgent {
    /// - Since: 4.26.0
    @_spi(SendbirdInternal) public class Info: NSObject, Codable {
        @_spi(SendbirdInternal) public var templateListToken: String?
        
        @_spi(SendbirdInternal) public init(
            templateListToken: String? = nil
        ) {
            self.templateListToken = templateListToken
        }
        
        @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodeCodingKeys.self)
            
            try container.encodeIfPresent(templateListToken, forKey: .templateListToken)
        }
        
        /// Default constructor.
        ///
        /// - Parameter decoder: `Decoder` instance
        @_spi(SendbirdInternal) public required init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodeCodingKeys.self)
            
            self.templateListToken = try container.decodeIfPresent(String.self, forKey: .templateListToken)
        }
    }
}
