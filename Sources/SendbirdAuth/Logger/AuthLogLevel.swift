//
//  AuthLogLevel.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/4/25.
//

import Foundation

public enum AuthLogLevel: Int, LogSymbol, Comparable, Codable {
    case verbose
    case debug
    case info
    case warning
    case error
    case none
    
    public var priority: Logger.Priority { .loggerLevel }
    
    public var symbol: String? {
        switch self {
        case .verbose:  return "verbose"
        case .debug:    return "debug"
        case .info:     return "info"
        case .warning:  return "warning"
        case .error:    return "error"
        case .none:     return nil
        }
    }
    
    public init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let symbol = self.symbol {
            try container.encode(symbol)
        }
    }
    
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue == rhs.rawValue }
}
