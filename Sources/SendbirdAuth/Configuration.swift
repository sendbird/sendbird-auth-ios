//
//  Configuration.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

import Foundation

enum Configuration {
    // MARK: - Environment URLs (hardcoded for SPM build config)

    #if RELEASE
        private static let defaultAPIHost = "https://api-@@.sendbird.com"
        private static let defaultWSHost = "wss://ws-@@.sendbird.com"
        private static let defaultBaseHost = "api-@@.sendbird.com"
    #else // NIGHTLYDEV when not RELEASE by default
        private static let defaultAPIHost = "https://api-nightlydev.sendbirdtest.com"
        private static let defaultWSHost = "wss://ws-nightlydev.sendbirdtest.com"
        private static let defaultBaseHost = "api-nightlydev.sendbirdtest.com"
    #endif

    private static func hostURL(for key: String, default defaultHost: String) -> String {
        // 1. Bundle Info.plist (xcframework)
        if let host = Bundle(for: SendbirdAuth.self).infoDictionary?[key] as? String {
            return host
        }
        // 2. Fallback to compile-time default
        return defaultHost
    }

    static func apiHostURL(for appId: String) -> String {
        let pref = SendbirdAuth.pref
        if let customAPIHost: String = pref.value(forKey: PreferenceKey.customAPIHost) {
            return customAPIHost
        }

        let template = hostURL(for: "API_HOST_URL", default: defaultAPIHost)
        return template.replacingOccurrences(of: "@@", with: appId)
    }

    static func wsHostURL(for appId: String) -> String {
        let pref = SendbirdAuth.pref
        if let customWsHost: String = pref.value(forKey: PreferenceKey.customWsHost) {
            return customWsHost
        }

        let template = hostURL(for: "WS_HOST_URL", default: defaultWSHost)
        return template.replacingOccurrences(of: "@@", with: appId)
    }

    static func baseHostURL(for appId: String) -> String? {
        let template = hostURL(for: "BASE_HOST_URL", default: defaultBaseHost)
        return template.replacingOccurrences(of: "@@", with: appId)
    }
}
