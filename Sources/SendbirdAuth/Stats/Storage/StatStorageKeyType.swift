//
//  StatStorageKeyType.swift
//  SendbirdChat
//
//  Created by Kai Lee on 2/21/25.
//

import Foundation

@_spi(SendbirdInternal) public protocol StatStorageKeyType {
    var lastSentAt: String { get }
    var wrapper: String { get }
    var queue: String { get }
}
