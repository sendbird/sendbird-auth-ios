//
//  String+SendBirdSDK.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/19.
//

import Foundation

@_spi(SendbirdInternal) public extension String {
    var hasElements: Bool { isEmpty == false }

    var collapsed: String? { isEmpty ? nil : self }

    var pathExtension: String? {
        guard contains("."), let ext = split(separator: ".").last else { return nil }
        return String(ext)
    }

    func occurencCount(of character: UniChar) -> Int {
        let cfString = self as CFString
        var inlineBuffer = CFStringInlineBuffer()
        let length = CFStringGetLength(cfString)
        CFStringInitInlineBuffer(cfString, &inlineBuffer, CFRange(location: 0, length: length))

        var counter = 0

        for index in 0 ... length {
            let char = CFStringGetCharacterFromInlineBuffer(&inlineBuffer, index)
            if char == character { counter += 1 }
        }

        return counter
    }

    func format(_ arguments: CVarArg...) -> String {
        let args = arguments.map {
            if let arg = $0 as? Int { return String(arg) }
            if let arg = $0 as? Float { return String(arg) }
            if let arg = $0 as? Double { return String(arg) }
            if let arg = $0 as? Int64 { return String(arg) }
            if let arg = $0 as? String { return String(arg) }
            return "(null)"
        } as [CVarArg]

        return String(format: self, arguments: args)
    }

    var utf8Data: Data {
        Data(utf8)
    }

    func validateFormat(pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        return regex.matches(
            in: self,
            range: NSRange(location: 0, length: utf16.count)
        ).count > 0
    }

    /// Appends "_index" to a String.
    func appendIndex(_ index: Int) -> String {
        return self + "_\(index)"
    }

    var asDeviceTokenData: Data? {
        let cleaned = replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()

        guard cleaned.isEmpty == false, cleaned.count % 2 == 0 else { return nil }

        var data = Data()
        for offset in stride(from: 0, to: cleaned.count, by: 2) {
            let substring = cleaned[cleaned.index(cleaned.startIndex, offsetBy: offset) ..< cleaned.index(cleaned.startIndex, offsetBy: offset + 2)]
            guard let byte = UInt8(substring, radix: 16) else { return nil }
            data.append(byte)
        }
        return data
    }

    static func isEqualJsonString(_ lhs: String, _ rhs: String) -> Bool {
        guard let data1 = lhs.data(using: .utf8),
              let data2 = rhs.data(using: .utf8)
        else {
            return false
        }

        do {
            let object1 = try JSONSerialization.jsonObject(with: data1, options: []) as? [String: Any]
            let object2 = try JSONSerialization.jsonObject(with: data2, options: []) as? [String: Any]

            // Convert both objects into JSON data and compare
            let normalizedData1 = try JSONSerialization.data(withJSONObject: object1 ?? [:], options: [.sortedKeys])
            let normalizedData2 = try JSONSerialization.data(withJSONObject: object2 ?? [:], options: [.sortedKeys])

            return normalizedData1 == normalizedData2
        } catch {
            return false
        }
    }
}

public extension String {
    @_spi(SendbirdInternal) init?(data: Data?) {
        guard let theData = data else {
            return nil
        }

        self.init(data: theData, encoding: .utf8)
    }

    @_spi(SendbirdInternal) init(prefix: String) {
        let compound = prefix + "." + UUID().uuidString
        self.init(compound)
    }

    @_spi(SendbirdInternal) func trunc(length: Int, trailing: String = "…") -> String {
        return (count > length) ? prefix(length) + trailing : self
    }

//    static var random: String {
//        return UUID().uuidString
//    }

    @_spi(SendbirdInternal) var urlEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: ".-_~ ")

        guard let encoded = addingPercentEncoding(withAllowedCharacters: allowed) else {
            return self
        }
        return encoded.replacingOccurrences(of: " ", with: "+")
    }
}

@_spi(SendbirdInternal) extension UniChar: Swift.ExpressibleByUnicodeScalarLiteral {
    @_spi(SendbirdInternal) public typealias UnicodeScalarLiteralType = UnicodeScalar

    @_spi(SendbirdInternal) public init(unicodeScalarLiteral scalar: UnicodeScalar) {
        self.init(scalar.value)
    }
}
