//
//  Response.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

public protocol RawDataRespondable {
    init(from rawData: Data) throws
}

public protocol Respondable: Command, Decodable {}

public struct VoidResponse: Respondable {}

extension Command where Self: Decodable {
    public static func decodeCommand(with data: Data?) -> Command? {
        guard let data = data else { return nil }
        guard let command = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        return command
    }
}

public struct EmptyResponse: Respondable {
    public init() {}
}

public typealias DecodableCommand = (Command & Decodable)

public enum SYEVCommandType: Int {
    case join = 10000
    case leave = 10001
    
    var valueType: DecodableCommand.Type? {
        switch self {
        case .join: return EmptyResponse.self
        case .leave: return EmptyResponse.self
        }
    }
}

public enum USERCommandType: String {
    case ban
    case unban

    var valueType: DecodableCommand.Type? {
        switch self {
        case .ban: return EmptyResponse.self
        case .unban: return EmptyResponse.self
        }
    }
}
