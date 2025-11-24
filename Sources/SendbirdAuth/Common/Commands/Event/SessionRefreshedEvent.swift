//
//  SessionRefreshedEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/10
//

import Foundation

public struct SessionRefreshedEvent: Decodable, SBCommand {
    public let cmd: CommandType = .login
    
    public let sessionKey: String?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        Logger.session.info("Got a new session key.")
        self.sessionKey = (try? container.decode(String.self, forKey: .key)) ??
            (try? container.decode(String.self, forKey: .newKey))
    }
}
