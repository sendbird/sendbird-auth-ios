//
//  InternalEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/01/14.
//

import Foundation

@_spi(SendbirdInternal) public protocol InternalEvent: Command {
    var dispatchSynchronously: Bool { get }
}

@_spi(SendbirdInternal) public extension InternalEvent {
    var dispatchSynchronously: Bool { true }
}
