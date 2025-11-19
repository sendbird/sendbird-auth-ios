//
//  ConnectionStateDataSource.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/15/25.
//

protocol ConnectionStateDataSource: AnyObject {
    var applicationId: String { get }
    var currentUser: AuthUser? { get }
}
