//
//  AuthLogLevel.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/4/25.
//

import Foundation

package enum AuthLogLevel: Int, LogSymbol, Comparable, Codable {
    case verbose
    case debug
    case info
    case warning
    case error
    case none
    
    package var priority: Logger.Priority { .loggerLevel }
    
    package var symbol: String? {
        switch self {
        case .verbose:  return "verbose"
        case .debug:    return "debug"
        case .info:     return "info"
        case .warning:  return "warning"
        case .error:    return "error"
        case .none:     return nil
        }
    }
    
    package init(from decoder: Decoder) throws {
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
    
    package func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let symbol = self.symbol {
            try container.encode(symbol)
        }
    }
    
    package static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    package static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue == rhs.rawValue }
}
