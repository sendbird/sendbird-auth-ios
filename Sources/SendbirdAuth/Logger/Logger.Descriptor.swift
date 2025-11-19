//
//  Logger.LogDescriptor.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/20.
//

import Foundation

protocol LogDescriptable {
    func result(with symbols: [String: LogSymbol], shouldAlwaysLog: Bool) -> String?
}

extension LogDescriptable {
    func result(filtered symbols: [String: LogSymbol]) -> String? {
        let value = symbols
            .map({ $0.value })
            .sortWithLogLevel()
            .compactMap({ $0.wrappedSymbol })
            .joined(separator: " ")
        
        if value.isEmpty == true { return nil }
        
        return value
    }
}

extension Logger {
    struct InternalDescriptor: LogDescriptable {
        func result(with symbols: [String: LogSymbol], shouldAlwaysLog: Bool) -> String? {
            if shouldAlwaysLog {
                return self.result(filtered: symbols)
            } else {
                #if TESTCASE
                return self.result(filtered: symbols)
                #else
                return nil
                #endif
            }
        }
    }
}

extension Logger {
    struct ExternalDescriptor: LogDescriptable {
        func result (with symbols: [String: LogSymbol], shouldAlwaysLog: Bool) -> String? {
            return self.result(filtered: symbols)
        }
    }
}
