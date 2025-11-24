//
//  SendbirdConfiguration.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

public class SendbirdConfiguration {
    public static let transferTimeoutDefault: TimeInterval = 60
    public static let webSocketTimoutDefault: TimeInterval = 10
    public static let socketResponseTimeoutDefault: TimeInterval = 10
    public static let requestTimeoutDefault = webSocketTimoutDefault + socketResponseTimeoutDefault
    
    public static let idleTyperDefaultTimeout: TimeInterval = 10
    
    public var useMemberInfoInMessage: Bool = true
    
    @BoundedRange(min: 0, max: .infinity, defaultValue: webSocketTimoutDefault)
    public var websocketTimeout: TimeInterval = 10
    
    @BoundedRange(min: 0, max: .infinity, defaultValue: transferTimeoutDefault)
    public var transferTimeout: TimeInterval = 60
    
    @BoundedRange(min: 5, max: 300, defaultValue: socketResponseTimeoutDefault)
    public var socketResponseTimeout: TimeInterval = 10
    
    public var requestTimeout: TimeInterval {
        websocketTimeout + socketResponseTimeout
    }
    
    public var pollIncludeDetails: Bool = true
    
    public var typingThrottleInterval: TimeInterval = 1
    
    @BoundedRange(
        propertyName: "sessionTokenRefreshTimeoutSec",
        min: 60,
        max: 1800
    )
    public var sessionTokenRefreshTimeoutSec: TimeInterval = 60
    
    public var typingIndicatorInvalidateTimeoutSec: TimeInterval = SendbirdConfiguration.idleTyperDefaultTimeout
    
    public init() {}
}
