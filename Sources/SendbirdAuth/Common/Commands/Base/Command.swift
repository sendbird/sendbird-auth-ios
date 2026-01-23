//
//  Command.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

@_spi(SendbirdInternal) public protocol Command { }

@_spi(SendbirdInternal) public enum CommandType: String, Decodable {
    case login = "LOGI"
    case userMessage = "MESG"
    case fileMessage = "FILE"
    case adminMessage = "ADMM"
    case broadcastMessage = "BRDM"
    case memberUpdateCount = "MCNT"
    case updateUserMessage = "MEDI"
    case updateFileMessage = "FEDI"
    case updateAdminMessage = "AEDI"
    case updatePoll = "PEDI"
    case votePoll = "VOTE"
    case deleteMessage = "DELM"
    case delivery =  "DLVR"
    case read = "READ"
    case reaction = "MRCT"
    case threads = "MTHD"
    case userEvent = "USEV"
    case systemEvent = "SYEV"
    case error = "EROR"

    case enterChannel = "ENTR"
    case exitChannel = "EXIT"
    case messageAck = "MACK"
    case typingStart = "TPST"
    case typingEnd = "TPEN"
    case ping = "PING"
    case pong = "PONG"
    case sessionExpired = "EXPR"
    
    case busy = "BUSY"  // 4.34.0
    
    @_spi(SendbirdInternal) public var isAckRequired: Bool {
        switch self {
        case .userMessage, .fileMessage,
             .enterChannel, .exitChannel,
             .read,
             .updateUserMessage, .updateFileMessage,
             .login,
             .votePoll:
            return true
        default: return false
        }
    }
}

@_spi(SendbirdInternal) public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
