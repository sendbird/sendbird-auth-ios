//
//  EventDelegate.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

package protocol EventDelegate: AnyObject {
    var priority: EventPriority { get }
    
    func didReceiveSBCommandEvent(command: SBCommand) async
    func didReceiveInternalEvent(command: InternalEvent)
}

extension EventDelegate {
    package var priority: EventPriority { .default }
}

// MARK: - Priority
package enum EventPriority: Int {
    case lowest = 1
    case low = 2
    case `default` = 3
    case high = 4
    case highest = 5
}

extension EventPriority: Comparable {
    package static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

