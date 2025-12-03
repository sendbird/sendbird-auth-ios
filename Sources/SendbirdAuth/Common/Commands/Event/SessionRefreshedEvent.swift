//
//  SessionRefreshedEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/10
//

import Foundation

@_spi(SendbirdInternal) public struct SessionRefreshedEvent: Decodable, SBCommand {
    @_spi(SendbirdInternal) public let cmd: CommandType = .login
    
    @_spi(SendbirdInternal) public let sessionKey: String?
    
    @_spi(SendbirdInternal) public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        Logger.session.info("Got a new session key.")
        self.sessionKey = (try? container.decode(String.self, forKey: .key)) ??
            (try? container.decode(String.self, forKey: .newKey))
    }
}
