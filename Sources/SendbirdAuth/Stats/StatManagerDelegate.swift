//
//  StatManagable.swift
//  SendbirdChatSDK
//
//  Created by Jed Gyeong on 3/7/24.
//

import Foundation

@_spi(SendbirdInternal) public protocol StatManagerDelegate: AnyObject {
    func statManager(_ statCollector: any StatCollectorContract, didFailSendStats: AuthError)
    func statManager(_ statCollector: any StatCollectorContract, newState: StatManager.State)
    func isStatManagerUploadable() -> Bool
    func statManager(_ statCollector: any StatCollectorContract, didSentStats: [any BaseStatType])
}
