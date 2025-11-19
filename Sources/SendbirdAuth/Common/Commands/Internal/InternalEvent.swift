//
//  InternalEvent.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/01/14.
//

import Foundation

package protocol InternalEvent: Command {
    var dispatchSynchronously: Bool { get }
}

package extension InternalEvent {
    var dispatchSynchronously: Bool { true }
}
