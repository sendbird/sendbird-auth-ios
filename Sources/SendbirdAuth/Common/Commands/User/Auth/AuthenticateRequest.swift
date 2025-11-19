//
//  AuthenticateRequest.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2023/07/06.
//

import Foundation

package struct AuthenticateRequest: APIRequestable {
    package let resultType = LoginEvent.self
    
    package init(
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
    
    package let headers: [String: String]
    
    package let method: HTTPMethod = .post
    
    package let url: URLPath

    package let applicationId: String
    package let expiringSession: Bool
    package let includeLOGI: Bool
    package let includeExtraData: String
    package let uikitConfig: Bool
    
    package let useLocalCache: Bool
    package let configTs: Int64

    package enum CodingKeys: String, CodingKey {
        case applicationId = "app_id"
        case expiringSession = "expiring_session"
    
        case includeLOGI = "include_logi"
        case includeExtraData = "include_extra_data"
        case uikitConfig = "uikit_config"
        case useLocalCache = "use_local_cache"
        case configTs = "config_ts"
    }
}
