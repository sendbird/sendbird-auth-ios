//
//  ErrorEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/29.
//

import Foundation

public struct ErrorEvent: Decodable, SBCommand {
    public let cmd: CommandType = .error
    
    public let code: Int
    public let message: String
    public let timestamp: Int64
    
    public let reqId: String?
    
    public let channelType: AuthChannelType?
    public let channelId: Int?
    public let channelURL: String?
    
    public init(
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
    
    public enum CodingKeys: String, CodingKey {
        case code
        case message
        case reqId = "req_id"
        case timestamp = "ts"
        case channelType = "channel_type"
        case channelId = "channel_id"
        case channelURL = "channel_url"
    }
    
    public var asAuthError: AuthError { AuthError(domain: message, code: code, userInfo: nil) }
}
