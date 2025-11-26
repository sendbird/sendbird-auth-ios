//
//  RequestHeaderDataSource.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

@_spi(SendbirdInternal) public protocol RequestHeaderDataSource: AnyObject {
    var requestHeaderContext: RequestHeadersContext? { get }
    var sessionDelegate: AuthSessionDelegate? { get }
    var configTs: Int64? { get }
}

extension RequestHeaderDataSource {
    @_spi(SendbirdInternal) public var isExpiringSession: Bool { sessionDelegate != nil }
}
