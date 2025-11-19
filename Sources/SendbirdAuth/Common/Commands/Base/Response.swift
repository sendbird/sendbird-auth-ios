//
//  Response.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

package protocol RawDataRespondable {
    init(from rawData: Data) throws
}

package protocol Respondable: Command, Decodable {}

package struct VoidResponse: Respondable {}

extension Command where Self: Decodable {
    package static func decodeCommand(with data: Data?) -> Command? {
        guard let data = data else { return nil }
        guard let command = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        return command
    }
}

package struct EmptyResponse: Respondable {
    package init() {}
}

package typealias DecodableCommand = (Command & Decodable)

package enum SYEVCommandType: Int {
    case join = 10000
    case leave = 10001
    
    var valueType: DecodableCommand.Type? {
        switch self {
        case .join: return EmptyResponse.self
        case .leave: return EmptyResponse.self
        }
    }
}

package enum USERCommandType: String {
    case ban
    case unban

    var valueType: DecodableCommand.Type? {
        switch self {
        case .ban: return EmptyResponse.self
        case .unban: return EmptyResponse.self
        }
    }
}
