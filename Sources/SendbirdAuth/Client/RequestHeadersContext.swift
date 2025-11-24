//
//  RequestHeadersContext.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/08/16.
//

import Foundation

public struct RequestHeadersContext {
    public let deviceVersion: String
    public let sdkVersion: String
    public let applicationId: String
    public let appVersion: String?
    public let extraDataString: String
    public let userAgent: String
    public let sbUserAgent: String
    public let sbSdkUserAgent: String
    public let sendbirdHeader: String
    public let isLocalCachingEnabled: Bool
    public let isIncludePollDetails: Bool
    public let inIncludeUIKitConfig: Bool
}
