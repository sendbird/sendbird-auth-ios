//
//  DummyRequest.swift
//  SendbirdChat
//
//  Created by Kai Lee on 4/28/25.
//

package struct DummyRequest: APIRequestable {
    package let method: HTTPMethod = .get
    package let url: URLPath = ""
    package init() {}
    
    package func encode(to encoder: Encoder) throws {}
}
