//
//  Logger.Symbols.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/20.
//

import Foundation
#if os(iOS)
import UIKit.UIDevice
#endif

@_spi(SendbirdInternal) public protocol LogSymbol {
    var symbol: String? { get }
    var priority: Logger.Priority { get }
    var wrappedSymbol: String? { get }
    var maskedSymbol: String? { get }
}

@_spi(SendbirdInternal) public extension LogSymbol {
    var symbolKey: String { priority.identifier }
    var wrappedSymbol: String? {
        guard let value = self.symbol?.uppercased() else { return nil }
        return "[\(value)]"
    }
    var maskedSymbol: String? { nil }
}

@_spi(SendbirdInternal) public extension Logger {
    /**
        LogSymbols will be printed like below by priority value.
        ```swift
        [dateFormat] [loggerLevel] [categories] [expression] [functionInfo] [tag] message ...
         ```
    */
    enum Priority: Int {
        // high
        case target
        case dateFormat
        case categories
        case loggerLevel
        case expression
        case functionInfo
        case tag
        case low
        // low
        
        var identifier: String { String(self.rawValue) }
    }
}

@_spi(SendbirdInternal) public extension Logger {
    typealias Level = AuthLogLevel
}
    
extension Logger {
    @_spi(SendbirdInternal) public struct Categories: OptionSet, LogSymbol {
        @_spi(SendbirdInternal) public let rawValue: Int
        
        static let external             = Categories(raw: .external)
        static let http                 = Categories(raw: .http)
        static let socket               = Categories(raw: .socket)
        static let client               = Categories(raw: .client)
        static let groupChannel         = Categories(raw: .groupChannel)
        static let openChannel          = Categories(raw: .openChannel)
        static let feedChannel          = Categories(raw: .feedChannel)
        static let session              = Categories(raw: .session)
        static let user                 = Categories(raw: .user)
        static let main                 = Categories(raw: .main)
        static let localCache           = Categories(raw: .localCache)
        static let messageCollection    = Categories(raw: .messageCollection)
        static let messageRepository    = Categories(raw: .messageRepository)
        static let messageDatabase      = Categories(raw: .messageDatabase)
        static let stat                 = Categories(raw: .stat)
        static let none                 = Categories(raw: .none)
        
        static let all: Categories = [
            .external,
            .http,
            .socket,
            .client,
            .groupChannel,
            .openChannel,
            .feedChannel,
            .session,
            .user,
            .main,
            .localCache,
            .stat,
            .messageCollection,
            .messageRepository,
            .messageDatabase,
            .none
        ]
        
        @_spi(SendbirdInternal) public var priority: Logger.Priority { .categories }
        
        @_spi(SendbirdInternal) public var symbol: String? {
            switch self {
            case .http:                 return "HTTP"
            case .socket:               return "Socket"
            case .client:               return "Client"
            case .groupChannel:         return "GroupChannel"
            case .openChannel:          return "OpenChannel"
            case .feedChannel:          return "FeedChannel"
            case .session:              return "Session"
            case .user:                 return "User"
            case .main:                 return "SendBirdChat"
            case .localCache:           return "LocalCache"
            case .stat:                 return "Stat"
            case .messageCollection:    return "MessageCollection"
            case .messageRepository:    return "MessageRepo"
            case .messageDatabase:      return "MessageDB"
            default:                    return nil
            }
        }
        
        @_spi(SendbirdInternal) public var wrappedSymbol: String? {
            guard let value = self.symbol else { return nil }
            return "[\(value)]"
        }
        
        @_spi(SendbirdInternal) public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}

@_spi(SendbirdInternal) public extension Logger.Categories {
    enum Raw: Int {
        case external, http, socket, client, groupChannel
        case feedChannel, openChannel, session, user, main, localCache, messageCollection, messageRepository, messageDatabase, stat, none
    }
    
    init(raw: Logger.Categories.Raw) { self = Logger.Categories(rawValue: 1 << raw.rawValue) }
}

extension Logger {
    @_spi(SendbirdInternal) public enum DateFormat: LogSymbol {
        case common
        case custom(String)
        
        @_spi(SendbirdInternal) public var priority: Logger.Priority { .dateFormat }
        
        var rawValue: String {
            switch self {
            case .common: return "yyyy.MM.dd HH:mm:ss.SSS Z"
            case .custom(let format): return format
            }
        }
        
        @_spi(SendbirdInternal) public var symbol: String? {
            let formatter = DateFormatter()
            formatter.dateFormat = self.rawValue
            formatter.timeZone = TimeZone.current
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter.string(from: Date())
        }
    }
}

extension Logger {
    enum Expression: LogSymbol {
        case file(String = #file)
        case function(String = #function)
        case line(Int = #line)
        case column(Int = #column)
        
        var priority: Logger.Priority { .expression }
        
        var symbol: String? {
            switch self {
            case .file(let value):      return value
            case .line(let value):      return String(value)
            case .column(let value):    return String(value)
            case .function(let value):  return value
            }
        }
        
        var wrappedSymbol: String? {
            switch self {
            case .file(let value):      return "[File: \(value)]"
            case .line(let value):      return "[Line: \(value)]"
            case .column(let value):    return "[Column: \(value)]"
            case .function(let value):  return "[Fuctnion: \(value)]"
            }
        }
    }
}

@_spi(SendbirdInternal) public extension Logger {
    enum Target: String, LogSymbol {
        case sendbirdChat = "SendbirdChat"
        case groupChannel = "GroupChannel"
        case openChannel = "OpenChannel"
        case feedChannel = "FeedChannel"
        
        @_spi(SendbirdInternal) public var priority: Logger.Priority { .target }
        
        @_spi(SendbirdInternal) public var value: String { self.rawValue }
        @_spi(SendbirdInternal) public var symbol: String? { self.value }
        @_spi(SendbirdInternal) public var wrappedSymbol: String? { self.symbol }
    }
    
    enum Tag: LogSymbol {
        case invoked(_ target: Target, _ function: String = #function)
        case success(_ target: Target, _ function: String = #function)
        case failure(_ target: Target, _ function: String = #function)
        case token(_ target: Target, _ selector: Selector)
        case event(_ target: Target, _ selector: Selector)
        case status(_ status: String)
        
        @_spi(SendbirdInternal) public var priority: Logger.Priority { .tag }
        
        @_spi(SendbirdInternal) public var symbol: String? {
            switch self {
            case .invoked(let target, let function):    return "[Invoked] \(target.value).\(function)"
            case .success(let target, let function):    return "[Success] \(target.value).\(function)"
            case .failure(let target, let function):    return "[Failure] \(target.value).\(function)"
            case .token(let target, let selector):      return "[Token] \(target.value).\(selector.description)"
            case .event(let target, let selector):      return "[Event] \(target.value).\(selector.description)"
            case .status(let status):                   return "[Status] \(status)"
            }
        }
        
        @_spi(SendbirdInternal) public var wrappedSymbol: String? { self.symbol }
    }
}

extension Logger {
    enum FunctionInfo: LogSymbol {
        case common(_ filepath: String = #file, _ function: String = #function, _ line: Int = #line)
        
        var priority: Logger.Priority { .functionInfo }
        
        var symbol: String? {
            switch self {
            case .common(let filepath, let function, let line):
                let filename = (filepath.components(separatedBy: "/").last ?? "").components(separatedBy: ".").first ?? ""
                return "[\(filename):\(function):\(line)]"
            }
        }
        
        var wrappedSymbol: String? { self.symbol }
    }
}

@_spi(SendbirdInternal) extension String: LogSymbol {
    @_spi(SendbirdInternal) public var priority: Logger.Priority { .low }
    @_spi(SendbirdInternal) public var symbol: String? { self }
    @_spi(SendbirdInternal) public var wrappedSymbol: String? { self.symbol }
    @_spi(SendbirdInternal) public var symbolKey: String { self }
    
    @_spi(SendbirdInternal) public static let separator = String(repeating: "=", count: 30)
}

extension AuthError: LogSymbol {
    @_spi(SendbirdInternal) public var priority: Logger.Priority { .low }
    @_spi(SendbirdInternal) public var symbol: String? { self.localizedDescription }
    @_spi(SendbirdInternal) public var wrappedSymbol: String? { "[code: \(self.code)] \(self.localizedDescription)" }
    var symbolKey: String { self.localizedDescription }
}

extension Dictionary where Key == String, Value == LogSymbol {
    var level: Logger.Level? {
        self[Logger.Priority.loggerLevel.identifier] as? Logger.Level
    }
    
    var category: Logger.Categories? {
        self[Logger.Priority.categories.identifier] as? Logger.Categories
    }
}

enum Masked: LogSymbol {
    var priority: Logger.Priority { .low }
    var symbol: String? {
        switch self {
        case .string(let symbol, _): return symbol?.symbol
        }
    }
    var wrappedSymbol: String? { self.symbol }
    var maskedSymbol: String? {
        switch self {
        case .string(_, let maskedSymbol): return maskedSymbol?.symbol
        }
    }
    
    case string(_ string: LogSymbol?, maskedString: LogSymbol?)
}

struct Variable: LogSymbol {
    var priority: Logger.Priority { .low }
    var symbol: String?
    
    var wrappedSymbol: String? { self.symbol }
    var maskedSymbol: String?
    
    init(_ name: String, content: LogSymbol?) {
        self.symbol = " \(name): \(content?.symbol ?? "nil")"
        self.maskedSymbol = nil
    }
    
    init(_ name: String, masking: LogSymbol?) {
        self.symbol = " \(name): \(masking?.symbol ?? "nil")"
        self.maskedSymbol = " \(name): \"*****\""
    }
}

extension Array where Element == LogSymbol {
    func sortWithLogLevel() -> [LogSymbol] { self.sorted { $0.priority.rawValue < $1.priority.rawValue } }
}
