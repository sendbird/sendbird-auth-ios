//
//  Request.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

@_spi(SendbirdInternal) public enum RequestIdentifier: Equatable, Hashable {
    @_spi(SendbirdInternal) public static func == (lhs: RequestIdentifier, rhs: RequestIdentifier) -> Bool {
        return lhs.hashValue == rhs.hashValue
    }
    // swiftlint:disable identifier_name
    case ws(_ type: CommandType)
    case api(_ path: URLPath, method: HTTPMethod)
    // swiftlint:enable identifier_name

    @_spi(SendbirdInternal) public func hash(into hasher: inout Hasher) {
        switch self {
        case .ws(let commandType):
            hasher.combine(commandType.rawValue)
        case .api(let path, let method):
            hasher.combine(path.asPath)
            hasher.combine(method.rawValue)
        }
    }
}

@_spi(SendbirdInternal) public protocol Requestable {
    var identifier: RequestIdentifier { get }
}

@_spi(SendbirdInternal) public protocol WSRequestable: Requestable, Encodable {
    var commandType: CommandType { get }
    var requestId: String? { get }
}

extension WSRequestable {
    @_spi(SendbirdInternal) public var requestId: String? { nil }
    @_spi(SendbirdInternal) public var identifier: RequestIdentifier { .ws(commandType) }
}

@_spi(SendbirdInternal) public class BaseWSRequest<T: Decodable>: ResultableWSRequest {
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        for body in additionalBodies {
            try body.encode(to: encoder)
        }

        try body.encode(to: encoder)

        if let requestId = requestId {
            var container = encoder.container(keyedBy: CodeCodingKeys.self)
            try container.encode(requestId, forKey: .reqId)
        }
    }

    @_spi(SendbirdInternal) public var resultType: T.Type

    @_spi(SendbirdInternal) public var commandType: CommandType
    @_spi(SendbirdInternal) public var requestId: String?

    @_spi(SendbirdInternal) public var body: RequestParameter
    @_spi(SendbirdInternal) public var additionalBodies: [Encodable]

    @_spi(SendbirdInternal) public init(
        commandType: CommandType,
        requestId: String?,
        body: RequestParameter,
        additionalBodies: [Encodable] = []
    ) {
        self.commandType = commandType
        self.requestId = requestId
        self.body = body
        self.additionalBodies = additionalBodies
        self.resultType = T.self
    }
}

@_spi(SendbirdInternal) public class APIRequest<T: Decodable>: APIRequestable {
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        for body in additionalBodies {
            try body.encode(to: encoder)
        }

        try body.encode(to: encoder)
    }

    @_spi(SendbirdInternal) public var resultType: T.Type

    @_spi(SendbirdInternal) public var method: HTTPMethod
    @_spi(SendbirdInternal) public var url: URLPath
    @_spi(SendbirdInternal) public var version: String

    @_spi(SendbirdInternal) public var body: RequestParameter

    @_spi(SendbirdInternal) public var headers: [String: String]
    @_spi(SendbirdInternal) public var additionalBodies: [Encodable]
    @_spi(SendbirdInternal) public var multipart: [String: Any]
    @_spi(SendbirdInternal) public var queryParameters: RequestParameter

    @_spi(SendbirdInternal) public var isSessionRequired: Bool // Request can be sent without session key
    @_spi(SendbirdInternal) public var isLoginRequired: Bool // Session key exists, but user data does not exist

    @_spi(SendbirdInternal) public var hasMultipart: Bool { !multipart.isEmpty }

    @_spi(SendbirdInternal) public init(
        method: HTTPMethod,
        url: some URLPathConvertible,
        version: String,
        body: RequestParameter,
        additionalBodies: [Encodable] = [],
        headers: [String: String],
        multipart: [String: Any],
        queryParameters: RequestParameter = .init(),
        isSessionRequired: Bool,
        isLoginRequired: Bool
    ) {
        self.method = method
        self.url = url.urlPath
        self.version = version
        self.body = body
        self.additionalBodies = additionalBodies
        self.headers = headers
        self.multipart = multipart
        self.queryParameters = queryParameters
        self.isSessionRequired = isSessionRequired
        self.isLoginRequired = isLoginRequired
        self.resultType = T.self
    }
}

@_spi(SendbirdInternal) public protocol APIRequestable: Encodable, Requestable, Resultable {
    typealias KeyEncodingStrategy = JSONEncoder.KeyEncodingStrategy

    var method: HTTPMethod { get }
    var url: URLPath { get }
    var version: String { get }

    var headers: [String: String] { get }
    var multipart: [String: Any] { get }
    var keyEncodingStrategy: KeyEncodingStrategy { get }
    var queryParameters: RequestParameter { get }

    // Request can be sent without session key
    var isSessionRequired: Bool { get }

    // Session key exists, but user data does not exist
    var isLoginRequired: Bool { get }
}

@_spi(SendbirdInternal) public extension APIRequestable {
    var headers: [String: String] { [:] }
    var version: String { "/v3" }
    var multipart: [String: Any] { [:] }
    var hasMultipart: Bool { !multipart.isEmpty }
    var keyEncodingStrategy: KeyEncodingStrategy { .useDefaultKeys }
    var isSessionRequired: Bool { true }
    var isLoginRequired: Bool { true }
    var identifier: RequestIdentifier { .api(url, method: method) }
    var queryParameters: RequestParameter { .param([:]) }
}

extension APIRequestable {
    // Default type for requests without associated response
    // Types that do have associated response type, re-define this property
    @_spi(SendbirdInternal) public var resultType: DefaultResponse.Type { DefaultResponse.self }
}
