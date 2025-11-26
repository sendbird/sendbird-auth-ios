//
//  AuthLogLevel.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/4/25.
//

import Foundation

@_spi(SendbirdInternal) public enum AuthLogLevel: Int, LogSymbol, Comparable, Codable {
    case verbose
    case debug
    case info
    case warning
    case error
    case none
    
    @_spi(SendbirdInternal) public var priority: Logger.Priority { .loggerLevel }
    
    @_spi(SendbirdInternal) public var symbol: String? {
        switch self {
        case .verbose:  return "verbose"
        case .debug:    return "debug"
        case .info:     return "info"
        case .warning:  return "warning"
        case .error:    return "error"
        case .none:     return nil
        }
    }
    
    @_spi(SendbirdInternal) public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        let string = try container.decode(String.self)
        switch string {
        case "verbose":     self = .verbose
        case "debug":       self = .debug
        case "info":        self = .info
        case "warning":     self = .warning
        case "error":       self = .error
        default:            self = .none
        }
    }
    
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let symbol = self.symbol {
            try container.encode(symbol)
        }
    }
    
    @_spi(SendbirdInternal) public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    @_spi(SendbirdInternal) public static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue == rhs.rawValue }
}
