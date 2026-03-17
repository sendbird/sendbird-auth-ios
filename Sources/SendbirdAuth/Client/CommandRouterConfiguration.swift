//
//  CommandRouterConfiguration.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/30/21.
//

import Foundation

@_spi(SendbirdInternal) public class CommandRouterConfiguration {
    @_spi(SendbirdInternal) public private(set) var cachePolicy: NSURLRequest.CachePolicy
    @_spi(SendbirdInternal) public private(set) var useNativeSocket: Bool?

    @_spi(SendbirdInternal) public var apiHost: String
    @_spi(SendbirdInternal) public var wsHost: String
    @_spi(SendbirdInternal) public var exceptionParser: APIExceptionParser

    @_spi(SendbirdInternal) public init(
        useNativeSocket: Bool? = nil,
        cachePolicy: NSURLRequest.CachePolicy,
        apiHost: String,
        wsHost: String,
        exceptionParser: APIExceptionParser = DefaultExceptionParser()
    ) {
        self.cachePolicy = cachePolicy
        self.useNativeSocket = useNativeSocket
        self.apiHost = apiHost
        self.wsHost = wsHost
        self.exceptionParser = exceptionParser
        Logger.main.info("API Host: \(apiHost)")
        Logger.main.info("WS Host: \(wsHost)")
    }

    // Only used for before `SendbirdChat.initWithApplicationId` is called
    @_spi(SendbirdInternal) public static let `default` = CommandRouterConfiguration(
        useNativeSocket: nil,
        cachePolicy: .useProtocolCachePolicy,
        apiHost: "",
        wsHost: "",
        exceptionParser: DefaultExceptionParser()
    )
    
    @_spi(SendbirdInternal) public func updateHost(apiHost: String?, wsHost: String?) {
        if let apiHost {
            self.apiHost = apiHost
        }
        if let wsHost {
            self.wsHost = wsHost
        }
    }
}
