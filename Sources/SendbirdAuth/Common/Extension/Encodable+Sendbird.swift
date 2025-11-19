//
//  Encodable+Sendbird.swift
//  
//
//  Created by Minhyuk Kim on 2021/06/23.
//

import Foundation

package extension JSONEncoder {
    convenience init(keyStrategy strategy: JSONEncoder.KeyEncodingStrategy) {
        self.init()
        self.keyEncodingStrategy = strategy
    }
}

package extension JSONDecoder {
    convenience init(keyStrategy strategy: JSONDecoder.KeyDecodingStrategy) {
        self.init()
        self.keyDecodingStrategy = strategy
    }
    
}

package protocol StrategyCodable: StrategyDecodable, StrategyEncodable { }

package protocol StrategyDecodable: Decodable {
    static var keyStrategy: JSONDecoder.KeyDecodingStrategy { get }
}

package protocol StrategyEncodable: Encodable {
    static var keyStrategy: JSONEncoder.KeyEncodingStrategy { get }
}

package extension StrategyEncodable {
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
