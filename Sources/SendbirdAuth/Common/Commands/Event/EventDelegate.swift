//
//  EventDelegate.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

@_spi(SendbirdInternal) public protocol EventDelegate: AnyObject {
    var priority: EventPriority { get }
    
    func didReceiveSBCommandEvent(command: SBCommand) async
    func didReceiveInternalEvent(command: InternalEvent)
}

extension EventDelegate {
    @_spi(SendbirdInternal) public var priority: EventPriority { .default }
}

// MARK: - Priority
@_spi(SendbirdInternal) public enum EventPriority: Int {
    case lowest = 1
    case low = 2
    case `default` = 3
    case high = 4
    case highest = 5
}

extension EventPriority: Comparable {
    @_spi(SendbirdInternal) public static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

