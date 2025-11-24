//
//  CommandRouterConfiguration.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/30/21.
//

import Foundation

public class CommandRouterConfiguration {
    public private(set) var cachePolicy: NSURLRequest.CachePolicy
    public private(set) var useNativeSocket: Bool?

    public var apiHost: String
    public var wsHost: String
    
    public init(
        useNativeSocket: Bool? = nil,
        cachePolicy: NSURLRequest.CachePolicy,
        apiHost: String,
        wsHost: String
    ) {
        self.cachePolicy = cachePolicy
        self.useNativeSocket = useNativeSocket
        self.apiHost = apiHost
        self.wsHost = wsHost
        Logger.main.info("API Host: \(apiHost)")
        Logger.main.info("WS Host: \(wsHost)")
    }
    
    // Only used for before `SendbirdChat.initWithApplicationId` is called
    public static let `default` = CommandRouterConfiguration(
        useNativeSocket: nil,
        cachePolicy: .useProtocolCachePolicy,
        apiHost: "",
        wsHost: ""
    )
    
    public func updateHost(apiHost: String?, wsHost: String?) {
        if let apiHost {
            self.apiHost = apiHost
        }
        if let wsHost {
            self.wsHost = wsHost
        }
    }
}
