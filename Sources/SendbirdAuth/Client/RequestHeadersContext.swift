//
//  RequestHeadersContext.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/08/16.
//

import Foundation

package struct RequestHeadersContext {
    package let deviceVersion: String
    package let sdkVersion: String
    package let applicationId: String
    package let appVersion: String?
    package let extraDataString: String
    package let userAgent: String
    package let sbUserAgent: String
    package let sbSdkUserAgent: String
    package let sendbirdHeader: String
    package let isLocalCachingEnabled: Bool
    package let isIncludePollDetails: Bool
    package let inIncludeUIKitConfig: Bool
}
