//
//  SendbirdConfiguration.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

package class SendbirdConfiguration {
    package static let transferTimeoutDefault: TimeInterval = 60
    package static let webSocketTimoutDefault: TimeInterval = 10
    package static let socketResponseTimeoutDefault: TimeInterval = 10
    package static let requestTimeoutDefault = webSocketTimoutDefault + socketResponseTimeoutDefault
    
    package static let idleTyperDefaultTimeout: TimeInterval = 10
    
    package var useMemberInfoInMessage: Bool = true
    
    @BoundedRange(min: 0, max: .infinity, defaultValue: webSocketTimoutDefault)
    package var websocketTimeout: TimeInterval = 10
    
    @BoundedRange(min: 0, max: .infinity, defaultValue: transferTimeoutDefault)
    package var transferTimeout: TimeInterval = 60
    
    @BoundedRange(min: 5, max: 300, defaultValue: socketResponseTimeoutDefault)
    package var socketResponseTimeout: TimeInterval = 10
    
    package var requestTimeout: TimeInterval {
        websocketTimeout + socketResponseTimeout
    }
    
    package var pollIncludeDetails: Bool = true
    
    package var typingThrottleInterval: TimeInterval = 1
    
    @BoundedRange(
        propertyName: "sessionTokenRefreshTimeoutSec",
        min: 60,
        max: 1800
    )
    package var sessionTokenRefreshTimeoutSec: TimeInterval = 60
    
    package var typingIndicatorInvalidateTimeoutSec: TimeInterval = SendbirdConfiguration.idleTyperDefaultTimeout
    
    package init() {}
}
