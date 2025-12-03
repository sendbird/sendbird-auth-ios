//
//  DummyRequest.swift
//  SendbirdChat
//
//  Created by Kai Lee on 4/28/25.
//

@_spi(SendbirdInternal) public struct DummyRequest: APIRequestable {
    @_spi(SendbirdInternal) public let method: HTTPMethod = .get
    @_spi(SendbirdInternal) public let url: URLPath = ""
    @_spi(SendbirdInternal) public init() {}
    
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {}
}
