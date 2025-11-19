//
//  CommandRouterConfiguration.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 7/30/21.
//

import Foundation

package class CommandRouterConfiguration {
    package private(set) var cachePolicy: NSURLRequest.CachePolicy
    package private(set) var useNativeSocket: Bool?

    package var apiHost: String
    package var wsHost: String
    
    package init(
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
    package static let `default` = CommandRouterConfiguration(
        useNativeSocket: nil,
        cachePolicy: .useProtocolCachePolicy,
        apiHost: "",
        wsHost: ""
    )
    
    package func updateHost(apiHost: String?, wsHost: String?) {
        if let apiHost {
            self.apiHost = apiHost
        }
        if let wsHost {
            self.wsHost = wsHost
        }
    }
}
