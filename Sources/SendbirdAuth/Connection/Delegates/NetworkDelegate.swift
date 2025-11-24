//
//  SBDNetworkDelegate.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/20/21.
//

import Foundation

/// Represents a delegate to receive network event
@objc(SBDNetworkDelegate)
public protocol NetworkDelegate {
    ///  Call when reconnection succeeds
    func didReconnect()
}
