//
//  Request.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

public enum RequestIdentifier: Equatable, Hashable {
    public static func == (lhs: RequestIdentifier, rhs: RequestIdentifier) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    // swiftlint:disable identifier_name
    case ws(_ type: CommandType)
    case api(_ path: URLPath, method: HTTPMethod)
    // swiftlint:enable identifier_name

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .ws(let commandType):
            hasher.combine(commandType.rawValue)
        case .api(let path, let method):
            hasher.combine(path.asPath)
            hasher.combine(method.rawValue)
        }
    }
}

public protocol Requestable {
    var identifier: RequestIdentifier { get }
}

public protocol WSRequestable: Requestable, Encodable {
    var commandType: CommandType { get }
    var requestId: String? { get }
}

extension WSRequestable {
    public var requestId: String? { nil }
    public var identifier: RequestIdentifier { .ws(commandType) }
}

public class BaseWSRequest<T: Decodable>: ResultableWSRequest {
    public func encode(to encoder: Encoder) throws {
        for body in additionalBodies {
            try? body.encode(to: encoder)
        }
        
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        for (key, value) in body {
            try? container.encode(value, forKey: key)
        }
        try? container.encode(requestId, forKey: .reqId)
    }
    
    public var resultType: T.Type
    
    public var commandType: CommandType
    public var requestId: String?
    
    public var body: [CodeCodingKeys: Encodable]
    public var additionalBodies: [Encodable]
    
    public init(
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

public class APIRequests<T: Decodable>: APIRequestable {
    public func encode(to encoder: Encoder) throws {
        for body in additionalBodies {
            try? body.encode(to: encoder)
        }
        
        var container = encoder.container(keyedBy: CodeCodingKeys.self)
        for (key, value) in body {
            try? container.encode(value, forKey: key)
        }
    }
    
    public var resultType: T.Type
    
    public var method: HTTPMethod
    public var url: URLPath
    public var version: String
    
    public var body: [CodeCodingKeys: Encodable]
    
    public var headers: [String: String]
    public var additionalBodies: [Encodable]
    public var multipart: [String: Any]
    
    public var isSessionRequired: Bool // Request can be sent without session key
    public var isLoginRequired: Bool // Session key exists, but user data does not exist
    
    public var hasMultipart: Bool { !multipart.isEmpty }
    
    public init(
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

public protocol APIRequestable: Encodable, Requestable, Resultable {
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

public extension APIRequestable {
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
    public var resultType: DefaultResponse.Type { DefaultResponse.self }
}
