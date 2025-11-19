//
//  Request.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

package enum RequestIdentifier: Equatable, Hashable {
    package static func == (lhs: RequestIdentifier, rhs: RequestIdentifier) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    // swiftlint:disable identifier_name
    case ws(_ type: CommandType)
    case api(_ path: URLPath, method: HTTPMethod)
    // swiftlint:enable identifier_name

    package func hash(into hasher: inout Hasher) {
        switch self {
        case .ws(let commandType):
            hasher.combine(commandType.rawValue)
        case .api(let path, let method):
            hasher.combine(path.asPath)
            hasher.combine(method.rawValue)
        }
    }
}

package protocol Requestable {
    var identifier: RequestIdentifier { get }
}

package protocol WSRequestable: Requestable, Encodable {
    var commandType: CommandType { get }
    var requestId: String? { get }
}

extension WSRequestable {
    package var requestId: String? { nil }
    package var identifier: RequestIdentifier { .ws(commandType) }
}

package class BaseWSRequest<T: Decodable>: ResultableWSRequest {
    package func encode(to encoder: Encoder) throws {
        for body in additionalBodies {
            try? body.encode(to: encoder)
        }
        
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        for (key, value) in body {
            try? container.encode(value, forKey: key)
        }
        try? container.encode(requestId, forKey: .reqId)
    }
    
    package var resultType: T.Type
    
    package var commandType: CommandType
    package var requestId: String?
    
    package var body: [CodeCodingKeys: Encodable]
    package var additionalBodies: [Encodable]
    
    package init(
        commandType: CommandType,
        requestId: String?,
        body: [CodeCodingKeys: Encodable?],
        additionalBodies: [Encodable] = []
    ) {
        self.commandType = commandType
        self.additionalBodies = additionalBodies.compactMap { $0 }
        self.body = body.compactMapValues { $0 }
        self.requestId = requestId
        self.resultType = T.self
    }
}

package class APIRequests<T: Decodable>: APIRequestable {
    package func encode(to encoder: Encoder) throws {
        for body in additionalBodies {
            try? body.encode(to: encoder)
        }
        
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        for (key, value) in body {
            try? container.encode(value, forKey: key)
        }
    }
    
    package var resultType: T.Type
    
    package var method: HTTPMethod
    package var url: URLPath
    package var version: String
    
    package var body: [CodeCodingKeys: Encodable]
    
    package var headers: [String: String]
    package var additionalBodies: [Encodable]
    package var multipart: [String: Any]
    
    package var isSessionRequired: Bool // Request can be sent without session key
    package var isLoginRequired: Bool // Session key exists, but user data does not exist
    
    package var hasMultipart: Bool { !multipart.isEmpty }
    
    package init(
        method: HTTPMethod,
        url: URLPaths,
        version: String,
        body: [CodeCodingKeys: Encodable?],
        additionalBodies: [Encodable] = [],
        headers: [String: String],
        multipart: [String: Any],
        isSessionRequired: Bool,
        isLoginRequired: Bool
    ) {
        self.method = method
        self.url = .init(array: url.splitPath)
        self.version = version
        self.additionalBodies = additionalBodies
        self.body = body.compactMapValues { $0 }
        self.headers = headers
        self.multipart = multipart
        self.isSessionRequired = isSessionRequired
        self.isLoginRequired = isLoginRequired
        self.resultType = T.self
    }
}

package protocol APIRequestable: Encodable, Requestable, Resultable {
    typealias KeyEncodingStrategy = JSONEncoder.KeyEncodingStrategy
    
    var method: HTTPMethod { get }
    var url: URLPath { get }
    var version: String { get }
    
    var headers: [String: String] { get }
    var multipart: [String: Any] { get }
    var keyEncodingStrategy: KeyEncodingStrategy { get }

    // Request can be sent without session key
    var isSessionRequired: Bool { get }
    
    // Session key exists, but user data does not exist
    var isLoginRequired: Bool { get }
}

package extension APIRequestable {
    var headers: [String: String] { [:] }
    var version: String { "/v3" }
    var multipart: [String: Any] { [:] }
    var hasMultipart: Bool { !multipart.isEmpty }
    var keyEncodingStrategy: KeyEncodingStrategy { .useDefaultKeys }
    var isSessionRequired: Bool { true }
    var isLoginRequired: Bool { true }
    var identifier: RequestIdentifier { .api(url, method: method) }
}

extension APIRequestable {
    // Default type for requests without associated response
    // Types that do have associated response type, re-define this property
    package var resultType: DefaultResponse.Type { DefaultResponse.self }
}
