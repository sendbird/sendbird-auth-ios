//
//  DefaultResponse.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

@_spi(SendbirdInternal) public struct DefaultResponse: Respondable, CustomStringConvertible {
    @_spi(SendbirdInternal) public let result: [String: Any]
    @_spi(SendbirdInternal) public var description: String { result.description }
    
    @_spi(SendbirdInternal) public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = (try? container.decode([String: AnyCodable].self))?.anyValue ?? [:]
        self.result = Dictionary().merging(dict, uniquingKeysWith: { (_, res) in
            res
        })
    }
}
