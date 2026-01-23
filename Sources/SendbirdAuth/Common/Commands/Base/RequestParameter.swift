//
//  RequestParameter.swift
//  SendbirdAuthSDK
//
//  Created by Kai Lee on 1/21/26.
//

import Foundation

@_spi(SendbirdInternal) public struct RequestParameter: Encodable {
    @_spi(SendbirdInternal) public let parameters: [String: Any]
    private let encodeBlock: (Encoder) throws -> Void
    private let codingKeyType: any RequestCodingKey.Type

    @_spi(SendbirdInternal) public init() {
        self.parameters = [:]
        self.encodeBlock = { _ in }
        self.codingKeyType = CodeCodingKeys.self
    }

    @_spi(SendbirdInternal) public init<T: RequestCodingKey>(_ dict: [T: Encodable?]) {
        let filteredDict = dict.compactMapValues { $0 }

        self.parameters = filteredDict.mapKeysToString()
        self.encodeBlock = { encoder in
            var container = encoder.container(keyedBy: T.self)
            for (key, value) in filteredDict {
                try container.encode(value, forKey: key)
            }
        }
        self.codingKeyType = T.self
    }

    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}

extension RequestParameter {
    /// To create RequestParameter with `CodeCodingKeys`, use this method.
    static func param(_ dict: [CodeCodingKeys: Encodable?]) -> RequestParameter {
        RequestParameter(dict)
    }

    /// Converts parameters to stringified dictionary for URL query encoding.
    func stringify() -> [String: String] {
        parameters.stringify()
    }
}
