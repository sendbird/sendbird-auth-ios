//
//  CodableUserDefault.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/06/03.
//

import Foundation

@propertyWrapper
@_spi(SendbirdInternal) public struct CodableUserDefault<Value: Codable> {
    
    private let key: String
    var userDefaults: UserDefaults
    
    @_spi(SendbirdInternal) public init(_ key: String, userDefaults: UserDefaults) {
        self.key = key
        self.userDefaults = userDefaults
    }
    
    @_spi(SendbirdInternal) public var wrappedValue: Value? {
        get {
            guard let data = userDefaults.object(forKey: key) as? Data else { return nil }

            do {
                return try JSONDecoder().decode(Value.self, from: data)
            } catch {
                Logger.external.error("[CodableUserDefault] decode error: \(error)")
                return nil
            }
        }
        set {
            guard let newValue = newValue else {
                userDefaults.removeObject(forKey: key)
                return
            }
            
            do {
                let encodedValue = try JSONEncoder().encode(newValue)
                userDefaults.setValue(encodedValue, forKey: key)
            } catch {
                Logger.external.error("[CodableUserDefault] encode error: \(error)")
            }
        }
    }
}
