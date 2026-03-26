//
//  SessionProvider.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 2026/02/02.
//

import Foundation

@_spi(SendbirdInternal) public protocol SessionObserver: AnyObject {
    var canRefreshSession: Bool { get }
    func sessionDidChange(_ session: Session?)
    func sessionRefreshRequested(for session: Session)
    func sessionRefreshFailed()
}

extension SessionObserver {
    @_spi(SendbirdInternal) public var canRefreshSession: Bool { true }
    @_spi(SendbirdInternal) public func sessionRefreshRequested(for session: Session) {}
    @_spi(SendbirdInternal) public func sessionRefreshFailed() {}
}
