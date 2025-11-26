//
//  SendbirdConfiguration.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

@_spi(SendbirdInternal) public class SendbirdConfiguration {
    @_spi(SendbirdInternal) public static let transferTimeoutDefault: TimeInterval = 60
    @_spi(SendbirdInternal) public static let webSocketTimoutDefault: TimeInterval = 10
    @_spi(SendbirdInternal) public static let socketResponseTimeoutDefault: TimeInterval = 10
    @_spi(SendbirdInternal) public static let requestTimeoutDefault = webSocketTimoutDefault + socketResponseTimeoutDefault
    
    @_spi(SendbirdInternal) public static let idleTyperDefaultTimeout: TimeInterval = 10
    
    @_spi(SendbirdInternal) public var useMemberInfoInMessage: Bool = true
    
    @BoundedRange(min: 0, max: .infinity, defaultValue: webSocketTimoutDefault)
    @_spi(SendbirdInternal) public var websocketTimeout: TimeInterval = 10
    
    @BoundedRange(min: 0, max: .infinity, defaultValue: transferTimeoutDefault)
    @_spi(SendbirdInternal) public var transferTimeout: TimeInterval = 60
    
    @BoundedRange(min: 5, max: 300, defaultValue: socketResponseTimeoutDefault)
    @_spi(SendbirdInternal) public var socketResponseTimeout: TimeInterval = 10
    
    @_spi(SendbirdInternal) public var requestTimeout: TimeInterval {
        websocketTimeout + socketResponseTimeout
    }
    
    @_spi(SendbirdInternal) public var pollIncludeDetails: Bool = true
    
    @_spi(SendbirdInternal) public var typingThrottleInterval: TimeInterval = 1
    
    @BoundedRange(
        propertyName: "sessionTokenRefreshTimeoutSec",
        min: 60,
        max: 1800
    )
    @_spi(SendbirdInternal) public var sessionTokenRefreshTimeoutSec: TimeInterval = 60
    
    @_spi(SendbirdInternal) public var typingIndicatorInvalidateTimeoutSec: TimeInterval = SendbirdConfiguration.idleTyperDefaultTimeout
    
    @_spi(SendbirdInternal) public init() {}
}
