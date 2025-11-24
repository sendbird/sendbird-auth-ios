//
//  DummyRequest.swift
//  SendbirdChat
//
//  Created by Kai Lee on 4/28/25.
//

public struct DummyRequest: APIRequestable {
    public let method: HTTPMethod = .get
    public let url: URLPath = ""
    public init() {}
    
    public func encode(to encoder: Encoder) throws {}
}
