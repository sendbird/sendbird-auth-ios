//
//  AuthenticateRequest.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2023/07/06.
//

import Foundation

public struct AuthenticateRequest: APIRequestable {
    public let resultType = LoginEvent.self
    
    public init(
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
    
    public let headers: [String: String]
    
    public let method: HTTPMethod = .post
    
    public let url: URLPath

    public let applicationId: String
    public let expiringSession: Bool
    public let includeLOGI: Bool
    public let includeExtraData: String
    public let uikitConfig: Bool
    
    public let useLocalCache: Bool
    public let configTs: Int64

    public enum CodingKeys: String, CodingKey {
        case applicationId = "app_id"
        case expiringSession = "expiring_session"
    
        case includeLOGI = "include_logi"
        case includeExtraData = "include_extra_data"
        case uikitConfig = "uikit_config"
        case useLocalCache = "use_local_cache"
        case configTs = "config_ts"
    }
}
