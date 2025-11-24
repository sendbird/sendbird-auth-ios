//
//  RequestHeadersBuilder.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/08/23.
//

import Foundation

public final class RequestHeadersBuilder {
    
    private var params: [String: String?]
    
    public init(_ params: [String: String?] = [:]) {
        self.params = params
    }
    
    /// Appends value for key
    /// - Parameters:
    ///   - key: The param key
    ///   - value: The param value
    public func append(key: String, value: String?) {
        params[key] = value
    }
    
    /// Appends boolean value for key
    /// - Parameters:
    ///   - key: The param key
    ///   - value: The boolean param value
    public func append(key: String, value: Bool) {
        params[key] = "\(value.asInt)"
    }
    
    /// Builds joined text for URL
    /// - Returns: The text for url params
    public func buildString() -> String {
        return params.compactMapValues { $0 }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
    }
    
    /// Builds JSON Dictionary for header
    /// - Returns: The JSON Dictionary for header
    public func buildDictionary() -> [String: String] {
        return params.compactMapValues { $0 }
    }
}
