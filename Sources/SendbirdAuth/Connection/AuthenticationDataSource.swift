//
//  AuthenticationDataSource.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/15/25.
//

public protocol AuthenticationDataSource: AnyObject {
    var currentUser: AuthUser? { get }
    var lastConnectedAt: Int64 { get }
    var authenticated: Bool { get }
}
