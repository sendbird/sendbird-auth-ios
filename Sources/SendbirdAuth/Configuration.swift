//
//  Configuration.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

import Foundation

struct Configuration {
    enum Environment {
        case production
        case test

        static var current: Environment {
#if TESTCASE
            return .test
#else
            return .production
#endif
        }

        var apiHostTemplate: String {
            switch self {
            case .production:
                return "https://api-@@.sendbird.com"
            case .test:
                return "https://test-api-@@.sendbird.com"
            }
        }

        var wsHostTemplate: String {
            switch self {
            case .production:
                return "wss://ws-@@.sendbird.com"
            case .test:
                return "wss://test-ws-@@.sendbird.com"
            }
        }

        var baseHostTemplate: String {
            switch self {
            case .production:
                return "api-@@.sendbird.com"
            case .test:
                return "test-api-@@.sendbird.com"
            }
        }
    }

    static func apiHostURL(for appId: String) -> String {
        let pref = SendbirdAuth.pref
        if let customAPIHost: String = pref.value(forKey: PreferenceKey.customAPIHost) {
            return customAPIHost
        }

        return Environment.current.apiHostTemplate.replacingOccurrences(of: "@@", with: appId)
    }

    static func wsHostURL(for appId: String) -> String {
        let pref = SendbirdAuth.pref
        if let customWsHost: String = pref.value(forKey: PreferenceKey.customWsHost) {
            return customWsHost
        }

        return Environment.current.wsHostTemplate.replacingOccurrences(of: "@@", with: appId)
    }

    static func baseHostURL(for appId: String) -> String? {
        return Environment.current.baseHostTemplate.replacingOccurrences(of: "@@", with: appId)
    }
}
