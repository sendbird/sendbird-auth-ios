//
//  Encodable+Sendbird.swift
//  
//
//  Created by Minhyuk Kim on 2021/06/23.
//

import Foundation

@_spi(SendbirdInternal) public extension JSONEncoder {
    convenience init(keyStrategy strategy: JSONEncoder.KeyEncodingStrategy) {
        self.init()
        self.keyEncodingStrategy = strategy
    }
}

@_spi(SendbirdInternal) public extension JSONDecoder {
    convenience init(keyStrategy strategy: JSONDecoder.KeyDecodingStrategy) {
        self.init()
        self.keyDecodingStrategy = strategy
    }
    
}

@_spi(SendbirdInternal) public protocol StrategyCodable: StrategyDecodable, StrategyEncodable { }

@_spi(SendbirdInternal) public protocol StrategyDecodable: Decodable {
    static var keyStrategy: JSONDecoder.KeyDecodingStrategy { get }
}

@_spi(SendbirdInternal) public protocol StrategyEncodable: Encodable {
    static var keyStrategy: JSONEncoder.KeyEncodingStrategy { get }
}

@_spi(SendbirdInternal) public extension StrategyEncodable {
    var keyStrategy: JSONEncoder.KeyEncodingStrategy { Self.keyStrategy }
}

@_spi(SendbirdInternal) public extension JSONDecoder {
    func updateAuthDependency(_ dependency: Dependency?) {
        if let dependency = dependency {
            self.userInfo[DecoderInfoKey.dependency] = WeakReference<AnyObject>(value: dependency)
        } else {
            self.userInfo[DecoderInfoKey.dependency] = nil
        }
    }
}

@_spi(SendbirdInternal) public extension Decoder {
    func extractAuthDependency() -> Dependency? {
        return (self.userInfo[DecoderInfoKey.dependency] as? WeakReference<AnyObject>)?.value as? Dependency
    }
}

extension Decoder {
    func extractDependency() -> Dependency? {
        return extractAuthDependency()
    }
}
