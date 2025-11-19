//
//  DefaultResponse.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

package struct DefaultResponse: Respondable, CustomStringConvertible {
    package let result: [String: Any]
    package var description: String { result.description }
    
    package init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = (try? container.decode([String: AnyCodable].self))?.anyValue ?? [:]
        self.result = Dictionary().merging(dict, uniquingKeysWith: { (_, res) in
            res
        })
    }
}
