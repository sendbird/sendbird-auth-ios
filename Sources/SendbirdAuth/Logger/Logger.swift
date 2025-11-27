//
//  Logger.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/20.
//

import Foundation

@_spi(SendbirdInternal) public struct Logger {
    var descriptor: LogDescriptable
    var symbols = [String: LogSymbol]()
    
    static private(set) var sdkVersion: String?
    
    fileprivate static var observers: [Logger.ObserverInfo] = [
        .init(observer: chatLoggerObserver)
    ]

    private static let chatLoggerObserver = ChatLoggerObserver()
    
    init(
        category: Logger.Categories = .none,
        dateFormat: Logger.DateFormat = .common,
        descriptor: LogDescriptable = InternalDescriptor()
    ) {
        self.symbols[category.symbolKey] = category
        self.symbols[dateFormat.symbolKey] = dateFormat
        self.descriptor = descriptor
    }
    
    static func add(observer: LoggerObserver) {
        self.remove(observer: observer)
        self.observers.append(Logger.ObserverInfo(observer: observer))
    }
    
    static func remove(observer: LoggerObserver) {
        self.observers.removeAll(where: { $0.observer?.identifier == observer.identifier })
    }
}

@_spi(SendbirdInternal) public extension Logger {
    static func setSDKVersion(_ version: String) {
        self.sdkVersion = version
    }

    static var external = Logger(category: .external, descriptor: ExternalDescriptor())
    static let http = Logger(category: .http, descriptor: ExternalDescriptor()) // 4.21.4
    static let socket = Logger(category: .socket, descriptor: ExternalDescriptor()) // 4.21.4
    static let client = Logger(category: .client)
    static let stat = Logger(category: .stat, descriptor: InternalDescriptor())
    static let groupChannel = Logger(category: .groupChannel, descriptor: ExternalDescriptor())
    static let openChannel = Logger(category: .openChannel, descriptor: ExternalDescriptor())
    static let feedChannel = Logger(category: .feedChannel, descriptor: ExternalDescriptor())
    static let session = Logger(category: .session, descriptor: ExternalDescriptor())
    static let user = Logger(category: .user, descriptor: ExternalDescriptor())
    static let main = Logger(category: .main, descriptor: ExternalDescriptor())
    static let localCache = Logger(category: .localCache, descriptor: ExternalDescriptor())
    static let messageCollection = Logger(category: .messageCollection, descriptor: ExternalDescriptor())
    static let messageRepository = Logger(category: .messageRepository, descriptor: ExternalDescriptor())
    static let messageDatabase = Logger(category: .messageDatabase, descriptor: ExternalDescriptor())
}

// MARK: Logger print methods for each levels.
extension Logger {
    @_spi(SendbirdInternal) public func error(category: Logger.Categories? = nil, tag: Logger.Tag? = nil, filepath: String = #file, line: Int = #line, funcName: String = #function, _ symbols: LogSymbol ...) { self.log(.error, category, tag, .common(filepath, funcName, line), symbols) }
    @_spi(SendbirdInternal) public func warning(category: Logger.Categories? = nil, tag: Logger.Tag? = nil, filepath: String = #file, line: Int = #line, funcName: String = #function, _ symbols: LogSymbol ...) { self.log(.warning, category, tag, .common(filepath, funcName, line), symbols) }
    @_spi(SendbirdInternal) public func info(category: Logger.Categories? = nil, tag: Logger.Tag? = nil, filepath: String = #file, line: Int = #line, funcName: String = #function, _ symbols: LogSymbol ...) { self.log(.info, category, tag, .common(filepath, funcName, line), symbols) }
    @_spi(SendbirdInternal) public func debug(category: Logger.Categories? = nil, tag: Logger.Tag? = nil, filepath: String = #file, line: Int = #line, funcName: String = #function, _ symbols: LogSymbol ...) { self.log(.debug, category, tag, .common(filepath, funcName, line), symbols) }
    @_spi(SendbirdInternal) public func verbose(category: Logger.Categories? = nil, tag: Logger.Tag? = nil, filepath: String = #file, line: Int = #line, funcName: String = #function, _ symbols: LogSymbol ...) { self.log(.verbose, category, tag, .common(filepath, funcName, line), symbols) }
    
    @_spi(SendbirdInternal) public func send(level: Logger.Level, category: Logger.Categories? = nil, tag: Logger.Tag? = nil, filepath: String = #file, line: Int = #line, funcName: String = #function, _ symbols: LogSymbol ...) { self.log(level, category, tag, .common(filepath, funcName, line), symbols) }
    
    // Prints the error log with `ErrorMessage`. You can use this method for convenience.
    @_spi(SendbirdInternal) public func error(errorMessage: ErrorMessage) {
        self.log(.error, nil, nil, nil, [errorMessage.description])
    }
}

extension Logger {
    fileprivate func log(_ level: Logger.Level, _ category: Logger.Categories?, _ tag: Logger.Tag?, _ functionInfo: Logger.FunctionInfo?, _ symbols: [LogSymbol]) {
        
        if let result = createLog(level, category, tag, functionInfo, symbols),
           let category = self.symbols.category {
            
            Logger.observers
                .compactMap { $0.observer }
                .filter { $0.categories.contains(category) }
                .filter { $0.limit <= level }
                .forEach { $0.log(message: result) }
        }
    }
    
    fileprivate func createLog(_ level: Logger.Level, _ category: Logger.Categories?, _ tag: Logger.Tag?, _ functionInfo: Logger.FunctionInfo?, _ symbols: [LogSymbol], isMasking: Bool = false, shouldAlwaysLog: Bool = false) -> String? {
        
        var values = self.symbols
        
        values[level.symbolKey] = level
        if let value = category { values[value.symbolKey] = value }
        if let value = tag { values[value.symbolKey] = value }
        
        let target = Target.sendbirdChat
        values[target.symbolKey] = target
        
        if let value = functionInfo { values[value.symbolKey] = value }
        
        symbols.forEach {
            if values[$0.symbolKey] == nil {
                if isMasking {
                    values[$0.symbolKey] = $0.maskedSymbol ?? $0.wrappedSymbol
                } else {
                    values[$0.symbolKey] = $0
                }
            } else {
                let symbol = isMasking ? ($0.maskedSymbol ?? $0.wrappedSymbol) : $0.wrappedSymbol
                values[$0.symbolKey] = "\(values[$0.symbolKey]?.wrappedSymbol ?? "") \(symbol ?? "")"
            }
        }
        
        guard let result = self.descriptor.result(with: values, shouldAlwaysLog: shouldAlwaysLog) else { return nil }
        
        return result
    }
}

// MARK: Logger filtering methods.
@_spi(SendbirdInternal) public extension Logger {
    static func setLoggerLevel(_ level: AuthLogLevel) {
        self.observers.forEach { $0.observer?.limit = level }
    }
    
    static func setCategories(_ categories: Logger.Categories) {
        self.observers.forEach { $0.observer?.categories = categories }
    }
}

@_spi(SendbirdInternal) public extension Logger {
    @discardableResult
    mutating func update(_ symbols: LogSymbol ...) -> Logger {
        symbols.forEach { self.symbols[$0.symbolKey] = $0 }
        return self
    }
}
