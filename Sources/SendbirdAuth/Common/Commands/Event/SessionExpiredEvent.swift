//
//  SessionExpiredEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/29.
//

import Foundation

@_spi(SendbirdInternal) public struct SessionExpiredEvent: Decodable, SBCommand {
    @_spi(SendbirdInternal) public let cmd: CommandType = .sessionExpired
    @_spi(SendbirdInternal) public let expiresIn: Int64?
    @_spi(SendbirdInternal) public let reason: AuthClientError?
    
    @_spi(SendbirdInternal) public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        self.expiresIn = try container.decodeIfPresent(Int64.self, forKey: .expiresIn)
        self.reason = try container.decodeIfPresent(AuthClientError.self, forKey: .reason)
    }
}
