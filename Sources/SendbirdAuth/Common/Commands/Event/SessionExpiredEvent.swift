//
//  SessionExpiredEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/29.
//

import Foundation

package struct SessionExpiredEvent: Decodable, SBCommand {
    package let cmd: CommandType = .sessionExpired
    package let expiresIn: Int64?
    package let reason: AuthClientError?
    
    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        self.expiresIn = try container.decodeIfPresent(Int64.self, forKey: .expiresIn)
        self.reason = try container.decodeIfPresent(AuthClientError.self, forKey: .reason)
    }
}
