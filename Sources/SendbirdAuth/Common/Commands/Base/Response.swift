//
//  Response.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

@_spi(SendbirdInternal) public protocol RawDataRespondable {
    init(from rawData: Data) throws
}

@_spi(SendbirdInternal) public protocol Respondable: Command, Decodable {}

@_spi(SendbirdInternal) public struct VoidResponse: Respondable {}

extension Command where Self: Decodable {
    @_spi(SendbirdInternal) public static func decodeCommand(with data: Data?) -> Command? {
        guard let data = data else { return nil }
        guard let command = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        return command
    }
}

@_spi(SendbirdInternal) public struct EmptyResponse: Respondable {
    @_spi(SendbirdInternal) public init() {}
}

@_spi(SendbirdInternal) public typealias DecodableCommand = (Command & Decodable)

@_spi(SendbirdInternal) public enum SYEVCommandType: Int {
    case join = 10000
    case leave = 10001
    
    var valueType: DecodableCommand.Type? {
        switch self {
        case .join: return EmptyResponse.self
        case .leave: return EmptyResponse.self
        }
    }
}

@_spi(SendbirdInternal) public enum USERCommandType: String {
    case ban
    case unban

    var valueType: DecodableCommand.Type? {
        switch self {
        case .ban: return EmptyResponse.self
        case .unban: return EmptyResponse.self
        }
    }
}
