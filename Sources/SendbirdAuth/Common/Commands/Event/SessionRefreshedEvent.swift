//
//  SessionRefreshedEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/10
//

import Foundation

package struct SessionRefreshedEvent: Decodable, SBCommand {
    package let cmd: CommandType = .login
    
    package let sessionKey: String?
    
    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        
        Logger.session.info("Got a new session key.")
        self.sessionKey = (try? container.decode(String.self, forKey: .key)) ??
            (try? container.decode(String.self, forKey: .newKey))
    }
}
