//
//  InternalEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/01/14.
//

import Foundation

public protocol InternalEvent: Command {
    var dispatchSynchronously: Bool { get }
}

public extension InternalEvent {
    var dispatchSynchronously: Bool { true }
}
