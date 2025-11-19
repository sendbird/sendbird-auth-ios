//
//  ErrorEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/29.
//

import Foundation

package struct ErrorEvent: Decodable, SBCommand {
    package let cmd: CommandType = .error
    
    package let code: Int
    package let message: String
    package let timestamp: Int64
    
    package let reqId: String?
    
    package let channelType: AuthChannelType?
    package let channelId: Int?
    package let channelURL: String?
    
    package init(
        code: Int,
        message: String,
        timestamp: Int64,
        reqId: String?,
        channelType: AuthChannelType?,
        channelId: Int?,
        channelURL: String?
    ) {
        self.code = code
        self.message = message
        self.timestamp = timestamp
        self.reqId = reqId
        self.channelType = channelType
        self.channelId = channelId
        self.channelURL = channelURL
    }
    
    package enum CodingKeys: String, CodingKey {
        case code
        case message
        case reqId = "req_id"
        case timestamp = "ts"
        case channelType = "channel_type"
        case channelId = "channel_id"
        case channelURL = "channel_url"
    }
    
    package var asAuthError: AuthError { AuthError(domain: message, code: code, userInfo: nil) }
}
