//
//  Dictionary+SendbirdChat.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/22.
//

import Foundation

public extension Dictionary {
    init(data: Data?) throws {
        guard let data = data,
              let jsonDict = try? JSONSerialization.jsonObject(
                with: data, options: .allowFragments
              ) as? [Key: Value] else {
            self = [:]
            return
        }

        self = jsonDict
    }

    func stringify() -> [String: String] where Key: CustomStringConvertible {
        return reduce(into: [String: String]()) { (result, element) in
            let key = element.key.description

            switch element.value {
            case let data as String: result[key] = data.urlEncoded
            case let data as Int where CFGetTypeID(element.value as CFTypeRef) == CFNumberGetTypeID():
                    result[key] = String(data)
            case let data as Bool where CFGetTypeID(element.value as CFTypeRef) == CFBooleanGetTypeID():
                    result[key] = String(data)
            case let data as [String]:
                result[key] = data.map { $0.urlEncoded }.joined(separator: ",")
            case let data as Encodable:
                result[key] = try? JSONEncoder().encode(data).utf8String
            default: ()
            }
        }
    }
    
    func adding<T: Encodable>(_ encodables: T...) -> [String: Any] where Key == String, Value == Encodable {
        return encodables.reduce(self) { result, encodable in
            guard let data = try? JSONEncoder().encode(encodable),
                  let other = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return result
            }
            
            return result.merging(other, uniquingKeysWith: { prev, _ in prev })
        }
    }
}

func == <K, L: Hashable, R: Hashable>(lhs: [K: L], rhs: [K: R]) -> Bool {
   (lhs as NSDictionary).isEqual(to: rhs)
}

public extension Dictionary where Value == AnyCodable {
    var anyValue: [Key: Any] { compactMapValues { $0.anyValue } } // anyValue 가 null 인 경우, 필드키가 제거됨.
}

public extension Dictionary where Value == Any {
    var anyCodable: [Key: AnyCodable] { self.mapValues { AnyCodable($0) } }
}
