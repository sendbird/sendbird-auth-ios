//
//  DefaultResponse.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

public struct DefaultResponse: Respondable, CustomStringConvertible {
    public let result: [String: Any]
    public var description: String { result.description }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = (try? container.decode([String: AnyCodable].self))?.anyValue ?? [:]
        self.result = Dictionary().merging(dict, uniquingKeysWith: { (_, res) in
            res
        })
    }
}
