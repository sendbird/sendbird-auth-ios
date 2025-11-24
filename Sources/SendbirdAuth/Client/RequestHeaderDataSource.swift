//
//  RequestHeaderDataSource.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

public protocol RequestHeaderDataSource: AnyObject {
    var requestHeaderContext: RequestHeadersContext? { get }
    var sessionDelegate: AuthSessionDelegate? { get }
    var configTs: Int64? { get }
}

extension RequestHeaderDataSource {
    public var isExpiringSession: Bool { sessionDelegate != nil }
}
