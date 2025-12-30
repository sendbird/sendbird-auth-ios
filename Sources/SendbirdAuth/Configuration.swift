//
//  Configuration.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

import Foundation

enum Configuration {
    // MARK: - Environment URLs (hardcoded for SPM build config)

    // NIGHTLYDEV when DEBUG by default.
    // Otherwise, set custom host in Info.plist or use `setCustomHost(_:)` API.
    #if DEBUG
        private static let defaultAPIHost = "https://api-nightlydev.sendbirdtest.com"
        private static let defaultWSHost = "wss://ws-nightlydev.sendbirdtest.com"
        private static let defaultBaseHost = "api-nightlydev.sendbirdtest.com"
    #else
        private static let defaultAPIHost = "https://api-@@.sendbird.com"
        private static let defaultWSHost = "wss://ws-@@.sendbird.com"
        private static let defaultBaseHost = "api-@@.sendbird.com"
    #endif

    private static func hostURL(for key: String, default defaultHost: String) -> String {
        // 1. Bundle Info.plist (xcframework)
        if let host = Bundle(for: SendbirdAuth.self).infoDictionary?[key] as? String {
            return host
        }
        // 2. Fallback to compile-time default
        return defaultHost
    }

    static func apiHostURL(for appId: String, using pref: LocalPreferences) -> String {
        if let customAPIHost: String = pref.value(forKey: PreferenceKey.customAPIHost) {
            return customAPIHost
        }

        let template = hostURL(for: "API_HOST_URL", default: defaultAPIHost)
        return template.replacingOccurrences(of: "@@", with: appId)
    }

    static func wsHostURL(for appId: String, using pref: LocalPreferences) -> String {
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

// MARK: - Custom Host Configuration

@_spi(SendbirdInternal) public extension SendbirdAuthMain {
    enum CustomHostEnvironment {
        case nightlydev
        case nightlyrel
        case no3
        case preprod
        case custom(apiHost: String, wsHost: String)

        var apiHost: String {
            switch self {
            case .nightlydev:
                return "https://api-nightlydev.sendbirdtest.com"
            case .nightlyrel:
                return "https://api-nightlyrel.sendbirdtest.com"
            case .no3:
                return "https://api-no3.sendbirdtest.com"
            case .preprod:
                return "https://api-preprod.sendbird.com"
            case let .custom(apiHost, _):
                return apiHost
            }
        }

        var wsHost: String {
            switch self {
            case .nightlydev:
                return "wss://ws-nightlydev.sendbirdtest.com"
            case .nightlyrel:
                return "wss://ws-nightlyrel.sendbirdtest.com"
            case .no3:
                return "wss://ws-no3.sendbirdtest.com"
            case .preprod:
                return "wss://ws-preprod.sendbird.com"
            case let .custom(_, wsHost):
                return wsHost
            }
        }
    }

    /// Sets custom host URLs for API and WebSocket connections.
    /// - Note: If you want to use release environment's host,
    ///        build configuration should be set to `Release` and clear custom host after setting it.
    func setCustomHost(_ environment: CustomHostEnvironment) {
        instancePref.set(value: environment.apiHost, forKey: PreferenceKey.customAPIHost)
        instancePref.set(value: environment.wsHost, forKey: PreferenceKey.customWsHost)
    }

    func clearCustomHost() {
        instancePref.remove(forKey: PreferenceKey.customAPIHost)
        instancePref.remove(forKey: PreferenceKey.customWsHost)
    }
}
