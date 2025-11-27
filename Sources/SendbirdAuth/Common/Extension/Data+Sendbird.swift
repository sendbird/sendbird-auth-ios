//
//  Data+SendbirdChat.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/26/21.
//

import Foundation
import CommonCrypto

@_spi(SendbirdInternal) public extension Data {
    var asDeviceTokenString: String {
        self.map { String(format: "%02.2hhx", $0) }.joined()
    }
    
    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }
}

@_spi(SendbirdInternal) public extension Data {
    
    var prettyPrintedJSONString: String {
        (try? JSONSerialization.jsonObject(with: self, options: []))
            .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted]) }
            .flatMap { String(data: $0, encoding: .utf8) }
        ?? String(describing: String(data: self, encoding: .utf8))
    }
    
    func aes256EncryptedData(with value: String) -> Data? {
        let salt = "NBh2KK8C".utf8Data
        let initialVector = "mTxPWHgDF3bLNhTg".utf8Data
        
        do {
            let key = try AES256Crypter.createKey(password: value.utf8Data, salt: salt)
            let aes = try AES256Crypter(key: key, initialVector: initialVector)
            let encryptedData = try aes.encrypt(self)
            
            return encryptedData
        } catch {
            return nil
        }
    }
    
    func aes256DecryptedData(with value: String) -> Data? {
        let salt = "NBh2KK8C".utf8Data
        let initialVector = "mTxPWHgDF3bLNhTg".utf8Data
        
        do {
            let key = try AES256Crypter.createKey(password: value.utf8Data, salt: salt)
            let aes = try AES256Crypter(key: key, initialVector: initialVector)
            let decryptedData = try aes.decrypt(self)
            
            return decryptedData
        } catch {
            return nil
        }
    }
    
}

@_spi(SendbirdInternal) public protocol Randomizer {
    static func randomInitialVector() -> Data?
    static func randomSalt() -> Data?
    static func randomData(length: Int) -> Data?
}

@_spi(SendbirdInternal) public protocol Crypter {
    func encrypt(_ digest: Data) throws -> Data
    func decrypt(_ encrypted: Data) throws -> Data
}

// https://medium.com/@vialyx/security-data-transforms-with-swift-aes256-on-ios-6509917497d
@_spi(SendbirdInternal) public struct AES256Crypter {
    
    private let key: Data
    private let initialVector: Data
    
    init(key: Data, initialVector: Data) throws {
        guard key.count == kCCKeySizeAES256 else {
            throw Error.badKeyLength
        }
        guard initialVector.count == kCCBlockSizeAES128 else {
            throw Error.badInputVectorLength
        }
        self.key = key
        self.initialVector = initialVector
    }
    
    enum Error: Swift.Error {
        case keyGeneration(status: Int)
        case cryptoFailed(status: CCCryptorStatus)
        case badKeyLength
        case badInputVectorLength
    }
    
    private func crypt(input: Data, operation: CCOperation) throws -> Data {
        var outLength = Int(0)
        var outBytes = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var status: CCCryptorStatus = CCCryptorStatus(kCCSuccess)
        input.withUnsafeBytes { encryptedBytes in
            initialVector.withUnsafeBytes { ivBytes in
                key.withUnsafeBytes { keyBytes in
                    status = CCCrypt(
                        operation,
                        CCAlgorithm(kCCAlgorithmAES128), // algorithm
                        CCOptions(kCCOptionPKCS7Padding), // options
                        keyBytes.baseAddress, // key
                        key.count, // keylength
                        ivBytes.baseAddress, // iv
                        encryptedBytes.baseAddress, // dataIn
                        input.count, // dataInLength
                        &outBytes, // dataOut
                        outBytes.count, // dataOutAvailable
                        &outLength // dataOutMoved
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw Error.cryptoFailed(status: status)
        }
        return Data(bytes: outBytes, count: outLength)
    }
    
    static func createKey(password: Data, salt: Data) throws -> Data {
        let length = kCCKeySizeAES256
        var status = Int32(0)
        var derivedBytes = [UInt8](repeating: 0, count: length)
        password.withUnsafeBytes { passwordBytes in
            salt.withUnsafeBytes { saltBytes in
                status = CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2), // algorithm
                    passwordBytes.baseAddress, // password
                    password.count, // passwordLen
                    saltBytes.baseAddress, // salt
                    salt.count, // saltLen
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1), // prf
                    10000, // rounds
                    &derivedBytes, // derivedKey
                    length // derivedKeyLen
                )
            }
        }
        guard status == 0 else {
            throw Error.keyGeneration(status: Int(status))
        }
        return Data(bytes: derivedBytes, count: length)
    }
    
}

extension AES256Crypter: Crypter {
    
    @_spi(SendbirdInternal) public func encrypt(_ digest: Data) throws -> Data {
        return try crypt(input: digest, operation: CCOperation(kCCEncrypt))
    }
    
    @_spi(SendbirdInternal) public func decrypt(_ encrypted: Data) throws -> Data {
        return try crypt(input: encrypted, operation: CCOperation(kCCDecrypt))
    }
}

extension AES256Crypter: Randomizer {
    
    @_spi(SendbirdInternal) public static func randomInitialVector() -> Data? {
        return randomData(length: kCCBlockSizeAES128)
    }
    
    @_spi(SendbirdInternal) public static func randomSalt() -> Data? {
        return randomData(length: 8)
    }
    
    @_spi(SendbirdInternal) public static func randomData(length: Int) -> Data? {
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { mutableBytes -> Int32 in
            guard let baseAddress = mutableBytes.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, length, baseAddress)
        }
        guard status == errSecSuccess else {
            return nil
        }
        return data
    }
    
}

@_spi(SendbirdInternal) public extension Data {
    func toHexString() -> String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}

extension Data {
    fileprivate func parse<Element: Decodable>(keyStrategy strategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) throws -> Element {
        return try JSONDecoder(keyStrategy: strategy).decode(Element.self, from: self)
    }
    
    fileprivate func parseList<Element: Decodable>(keyStrategy strategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys) throws -> [Element] {
        return try JSONDecoder(keyStrategy: strategy).decode([Element].self, from: self)
    }
}
