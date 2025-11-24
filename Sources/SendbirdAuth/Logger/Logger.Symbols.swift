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

public protocol LogSymbol {
    var symbol: String? { get }
    var priority: Logger.Priority { get }
    var wrappedSymbol: String? { get }
    var maskedSymbol: String? { get }
}

public extension LogSymbol {
    var symbolKey: String { priority.identifier }
    var wrappedSymbol: String? {
        guard let value = self.symbol?.uppercased() else { return nil }
        return "[\(value)]"
    }
    var maskedSymbol: String? { nil }
}

public extension Logger {
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

public extension Logger {
    typealias Level = AuthLogLevel
}
    
extension Logger {
    public struct Categories: OptionSet, LogSymbol {
        public let rawValue: Int
        
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
        
        public var priority: Logger.Priority { .categories }
        
        public var symbol: String? {
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
        
        public var wrappedSymbol: String? {
            guard let value = self.symbol else { return nil }
            return "[\(value)]"
        }
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }
}

public extension Logger.Categories {
    enum Raw: Int {
        case external, http, socket, client, groupChannel
        case feedChannel, openChannel, session, user, main, localCache, messageCollection, messageRepository, messageDatabase, stat, none
    }
    
    init(raw: Logger.Categories.Raw) { self = Logger.Categories(rawValue: 1 << raw.rawValue) }
}

extension Logger {
    public enum DateFormat: LogSymbol {
        case common
        case custom(String)
        
        public var priority: Logger.Priority { .dateFormat }
        
        var rawValue: String {
            switch self {
            case .common: return "yyyy.MM.dd HH:mm:ss.SSS Z"
            case .custom(let format): return format
            }
        }
        
        public var symbol: String? {
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

public extension Logger {
    enum Target: String, LogSymbol {
        case sendbirdChat = "SendbirdChat"
        case groupChannel = "GroupChannel"
        case openChannel = "OpenChannel"
        case feedChannel = "FeedChannel"
        
        public var priority: Logger.Priority { .target }
        
        public var value: String { self.rawValue }
        public var symbol: String? { self.value }
        public var wrappedSymbol: String? { self.symbol }
    }
    
    enum Tag: LogSymbol {
        case invoked(_ target: Target, _ function: String = #function)
        case success(_ target: Target, _ function: String = #function)
        case failure(_ target: Target, _ function: String = #function)
        case token(_ target: Target, _ selector: Selector)
        case event(_ target: Target, _ selector: Selector)
        case status(_ status: String)
        
        public var priority: Logger.Priority { .tag }
        
        public var symbol: String? {
            switch self {
            case .invoked(let target, let function):    return "[Invoked] \(target.value).\(function)"
            case .success(let target, let function):    return "[Success] \(target.value).\(function)"
            case .failure(let target, let function):    return "[Failure] \(target.value).\(function)"
            case .token(let target, let selector):      return "[Token] \(target.value).\(selector.description)"
            case .event(let target, let selector):      return "[Event] \(target.value).\(selector.description)"
            case .status(let status):                   return "[Status] \(status)"
            }
        }
        
        public var wrappedSymbol: String? { self.symbol }
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

extension String: LogSymbol {
    public var priority: Logger.Priority { .low }
    public var symbol: String? { self }
    public var wrappedSymbol: String? { self.symbol }
    var symbolKey: String { self }
    
    static let separator = String(repeating: "=", count: 30)
}

extension AuthError: LogSymbol {
    public var priority: Logger.Priority { .low }
    public var symbol: String? { self.localizedDescription }
    public var wrappedSymbol: String? { "[code: \(self.code)] \(self.localizedDescription)" }
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
