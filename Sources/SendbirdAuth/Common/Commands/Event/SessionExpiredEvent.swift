//
//  SessionExpiredEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/29.
//

import Foundation

public struct SessionExpiredEvent: Decodable, SBCommand {
    public let cmd: CommandType = .sessionExpired
    public let expiresIn: Int64?
    public let reason: AuthClientError?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        self.expiresIn = try container.decodeIfPresent(Int64.self, forKey: .expiresIn)
        self.reason = try container.decodeIfPresent(AuthClientError.self, forKey: .reason)
    }
}
