//
//  RequestHeadersContext.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/08/16.
//

import Foundation

@_spi(SendbirdInternal) public struct RequestHeadersContext {
    @_spi(SendbirdInternal) public let deviceVersion: String
    @_spi(SendbirdInternal) public let sdkVersion: String
    @_spi(SendbirdInternal) public let applicationId: String
    @_spi(SendbirdInternal) public let appVersion: String?
    @_spi(SendbirdInternal) public let extraDataString: String
    @_spi(SendbirdInternal) public let userAgent: String
    @_spi(SendbirdInternal) public let sbUserAgent: String
    @_spi(SendbirdInternal) public let sbSdkUserAgent: String
    @_spi(SendbirdInternal) public let sendbirdHeader: String
    @_spi(SendbirdInternal) public let isLocalCachingEnabled: Bool
    @_spi(SendbirdInternal) public let isIncludePollDetails: Bool
    @_spi(SendbirdInternal) public let inIncludeUIKitConfig: Bool
}
