//
//  URLRequest+SendbirdSDK.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/05/26.
//

import Foundation

public extension URLRequest {
    
    var logDescription: String {
        var result = "[\(httpMethod ?? "")] \(url?.absoluteString ?? "")"
        if let httpHeaderFieldsDescription = httpHeaderFieldsDescription {
            result += "\nHeaders: \(httpHeaderFieldsDescription)"
        }
        
        if let bodyDescription = bodyDescription {
            result += "\nBody: \(bodyDescription)"
        }
        
        return result
    }
    
    private var httpHeaderFieldsDescription: String? {
        guard var headers = allHTTPHeaderFields, !headers.isEmpty else {
            return nil
        }
        
        #if !TESTCASE
        headers["Session-Key"] = "********"
        #endif
        
        return (try? JSONSerialization.data(withJSONObject: headers, options: [.prettyPrinted]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
        
    private var bodyDescription: String? {
        guard let body = httpBody else {
            return nil
        }
        
        return (try? JSONSerialization.jsonObject(with: body, options: []))
            .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: .prettyPrinted) }
            .flatMap { String(data: $0, encoding: .utf8) }
    }
    
}

extension URLRequest {
    
    /// milliSeconds
    var requestSentTimestamp: Int64? {
        value(forHTTPHeaderField: "Request-Sent-Timestamp")
            .flatMap({ Double($0) })
            .flatMap({ Int64($0) })
    }
}
