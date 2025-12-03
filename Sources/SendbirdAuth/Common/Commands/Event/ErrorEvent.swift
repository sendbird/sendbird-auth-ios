//
//  ErrorEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/29.
//

import Foundation

@_spi(SendbirdInternal) public struct ErrorEvent: Decodable, SBCommand {
    @_spi(SendbirdInternal) public let cmd: CommandType = .error
    
    @_spi(SendbirdInternal) public let code: Int
    @_spi(SendbirdInternal) public let message: String
    @_spi(SendbirdInternal) public let timestamp: Int64
    
    @_spi(SendbirdInternal) public let reqId: String?
    
    @_spi(SendbirdInternal) public let channelType: AuthChannelType?
    @_spi(SendbirdInternal) public let channelId: Int?
    @_spi(SendbirdInternal) public let channelURL: String?
    
    @_spi(SendbirdInternal) public init(
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
    
    @_spi(SendbirdInternal) public enum CodingKeys: String, CodingKey {
        case code
        case message
        case reqId = "req_id"
        case timestamp = "ts"
        case channelType = "channel_type"
        case channelId = "channel_id"
        case channelURL = "channel_url"
    }
    
    @_spi(SendbirdInternal) public var asAuthError: AuthError { AuthError(domain: message, code: code, userInfo: nil) }
}
