//
//  SDKInfo.swift
//  SendbirdChat
//
//  Created by Kai Lee on 10/21/25.
//

import Foundation

/// Sendbird extension SDK info class, used in SDK user agent.
/// - since: 4.31.1
@_spi(SendbirdInternal) public struct SendbirdSDKInfo {
    @_spi(SendbirdInternal) public let product: SendbirdProduct
    @_spi(SendbirdInternal) public let platform: SendbirdPlatform
    @_spi(SendbirdInternal) public let version: String

    /// Parameter constructor
    @_spi(SendbirdInternal) public init(product: SendbirdProduct, platform: SendbirdPlatform, version: String) {
        self.product = product
        self.platform = platform
        self.version = version
    }

    /// Checks if sdkVersion follows semVer convention.
    @_spi(SendbirdInternal) public func validateVersionFormat() -> Bool {
        let semVerPattern = "^\\d+\\.\\d+\\.\\d+(?:-[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*)?(?:\\+[a-zA-Z0-9-]+(?:\\.[a-zA-Z0-9-]+)*)?$"
        return version.validateFormat(pattern: semVerPattern)
    }

    @_spi(SendbirdInternal) public func toString() -> String {
        // e.g. "uikit/iOS/3.3.2"
        return "\(product.rawValue)/\(platform.rawValue)/\(version)"
    }
}

// MARK: - SB SDK User Agent

/// A list of Sendbird products that use Sendbird Chat.
@_spi(SendbirdInternal) public enum SendbirdProduct: String {
    case chat
    case calls
    case desk
    case live
    case uikitChat = "uikit-chat"
    case uikitLive = "uikit-live"
    case swiftuiChat = "swiftui-chat"
    case aiagent = "ai-agent"
}

/// A list of platforms that use Sendbird Chat.
@_spi(SendbirdInternal) public enum SendbirdPlatform: String {
    case ios
    case android
    case javascript = "js"
    case unreal
    case unity
    case reactNative = "react-native"
    case flutter
}
