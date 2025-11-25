//
//  Codable+SendbirdChat.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/22.
//

import Foundation

extension Encodable {
    public func toDictionary(
        options: [CodingUserInfoKey: Any] = [:],
        keyStrategy strategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys
    ) -> [String: Any]? {
        let encoder = JSONEncoder()
        encoder.userInfo = options
        encoder.dataEncodingStrategy = .base64
        encoder.keyEncodingStrategy = strategy
        guard let data = try? encoder.encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: [.allowFragments])) as? [String: Any]
    }
}

extension Decodable where Self: Encodable {
    public func makeCodableCopy(options: [CodingUserInfoKey: Any] = [:], decoder: JSONDecoder) -> Self {
        do {
            let encoder = JSONEncoder()
            encoder.userInfo = options
            encoder.dataEncodingStrategy = .base64
            let encodedData = try encoder.encode(self)
            let obj = try decoder.decode(Self.self, from: encodedData)
            return obj
        } catch { fatalError("Failed to make a copy of \(self).") }
    }
}

extension Encodable {
    public func makeCodableCopy<T: Decodable>(as type: T.Type, decoder: JSONDecoder) -> T? {
        do {
            let encodedData = try JSONEncoder().encode(self)
            return try decoder.decode(type, from: encodedData)
        } catch { return nil }
    }
}

// Internal method for chat
public extension Decodable {
    static func _make(_ json: [AnyHashable: Any]) -> Self? {
        return Self._make(from: json, decoder: SendbirdAuth.authDecoder)
    }
    
    static func _make(from json: [AnyHashable: Any], decoder: JSONDecoder) -> Self? {
        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: [])
            let object = try decoder.decode(Self.self, from: data)
            return object
        } catch {
            return nil
        }
    }
}

extension KeyedDecodingContainer {
    /// Try to decode a Bool as Int then String before decoding as Bool.
    ///
    /// - Parameter key: Key.
    /// - Returns: Decoded Bool value.
    /// - Throws: Decoding error.
    public func decodeBoolAsIntOrString(forKey key: Key) throws -> Bool {
        if let bool = try? decode(Bool.self, forKey: key) {
            return bool
        }
        if let bool = try? decode(String.self, forKey: key) {
            return bool == "1"
        }
        let int = try decode(Int.self, forKey: key)
        return int == 1
    }
    
    /// Try to decode a Bool as Int then String before decoding as Bool if present.
    ///
    /// - Parameter key: Key.
    /// - Returns: Decoded Bool value.
    /// - Throws: Decoding error.
    public func decodeBoolAsIntOrStringIfPresent(forKey key: Key) throws -> Bool? {
        if let bool = try? decodeIfPresent(Bool.self, forKey: key) {
            return bool
        }
        if let bool = try? decodeIfPresent(String.self, forKey: key) {
            return bool == "1"
        }
        if let int = try? decodeIfPresent(Int.self, forKey: key) {
            return int == 1
        }
        return nil
    }
}
