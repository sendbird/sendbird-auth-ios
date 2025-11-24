//
//  Encodable+Sendbird.swift
//  
//
//  Created by Minhyuk Kim on 2021/06/23.
//

import Foundation

public extension JSONEncoder {
    convenience init(keyStrategy strategy: JSONEncoder.KeyEncodingStrategy) {
        self.init()
        self.keyEncodingStrategy = strategy
    }
}

public extension JSONDecoder {
    convenience init(keyStrategy strategy: JSONDecoder.KeyDecodingStrategy) {
        self.init()
        self.keyDecodingStrategy = strategy
    }
    
}

public protocol StrategyCodable: StrategyDecodable, StrategyEncodable { }

public protocol StrategyDecodable: Decodable {
    static var keyStrategy: JSONDecoder.KeyDecodingStrategy { get }
}

public protocol StrategyEncodable: Encodable {
    static var keyStrategy: JSONEncoder.KeyEncodingStrategy { get }
}

public extension StrategyEncodable {
    var keyStrategy: JSONEncoder.KeyEncodingStrategy { Self.keyStrategy }
}

extension JSONDecoder {
    func updateDependency(_ dependency: Dependency?) {
        self.userInfo[DecoderInfoKey.dependency] = dependency
    }
}

extension Decoder {
    func extractDependency() -> Dependency? {
        return self.userInfo[DecoderInfoKey.dependency] as? Dependency
    }
}
