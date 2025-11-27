//
//  AuthenticateRequest.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2023/07/06.
//

import Foundation

@_spi(SendbirdInternal) public struct AuthenticateRequest: APIRequestable {
    @_spi(SendbirdInternal) public let resultType = LoginEvent.self
    
    @_spi(SendbirdInternal) public init(
        userId: String,
        applicationId: String,
        authToken: String? = nil,
        expiringSession: Bool,
        requestHeaderDataSource: RequestHeaderDataSource?,
        includeLOGI: Bool,
        useLocalCache: Bool
    ) {
        if let authToken {
            self.headers = ["Access-Token": authToken]
        } else {
            self.headers = [:]
        }
        
        self.url = ["sdk", "users", userId, "authentication"]
        self.applicationId = applicationId
        self.expiringSession = expiringSession
        self.includeLOGI = includeLOGI
        self.includeExtraData = requestHeaderDataSource?.requestHeaderContext?.extraDataString ?? ""
        self.uikitConfig = (requestHeaderDataSource?.requestHeaderContext?.inIncludeUIKitConfig ?? true) == true
        self.useLocalCache = useLocalCache
        self.configTs = requestHeaderDataSource?.configTs ?? 0
    }
    
    @_spi(SendbirdInternal) public let headers: [String: String]
    
    @_spi(SendbirdInternal) public let method: HTTPMethod = .post
    
    @_spi(SendbirdInternal) public let url: URLPath

    @_spi(SendbirdInternal) public let applicationId: String
    @_spi(SendbirdInternal) public let expiringSession: Bool
    @_spi(SendbirdInternal) public let includeLOGI: Bool
    @_spi(SendbirdInternal) public let includeExtraData: String
    @_spi(SendbirdInternal) public let uikitConfig: Bool
    
    @_spi(SendbirdInternal) public let useLocalCache: Bool
    @_spi(SendbirdInternal) public let configTs: Int64

    @_spi(SendbirdInternal) public enum CodingKeys: String, CodingKey {
        case applicationId = "app_id"
        case expiringSession = "expiring_session"
    
        case includeLOGI = "include_logi"
        case includeExtraData = "include_extra_data"
        case uikitConfig = "uikit_config"
        case useLocalCache = "use_local_cache"
        case configTs = "config_ts"
    }
}
