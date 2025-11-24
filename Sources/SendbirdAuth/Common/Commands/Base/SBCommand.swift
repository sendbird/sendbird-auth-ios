//
//  SBCommand.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/29.
//

import Foundation

public protocol SBCommand: Command, Decodable {
    var cmd: CommandType { get }
    
    var reqId: String? { get }
    var requestId: String { get }
    
    var uniqueId: String? { get }
}

public extension SBCommand {
    /// For more information, see [req_id vs request_id](https://sendbird.atlassian.net/wiki/spaces/SDK/pages/1723140230/req+id+vs+request+id)
    var reqId: String? { nil }
    var requestId: String { "" }
    
    var uniqueId: String? { nil }
    
    var isAckFromCurrentDeviceRequest: Bool { reqId != nil }
}
