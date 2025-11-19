//
//  Configuration.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

import Foundation

struct Configuration {
    static func apiHostURL(for appId: String) -> String {
        let pref = SendbirdAuth.pref
        if let customAPIHost: String = pref.value(forKey: PreferenceKey.customAPIHost) {
            return customAPIHost
        }
        
#if TESTCASE
        guard let host = (Bundle(for: SendbirdAuth.self).infoDictionary?["API_HOST_URL"] as? String)?.replacingOccurrences(of: "@@", with: appId) else {
            assertionFailure("unresolved api host!")
            return ""
        }
        return host
#else
        return "https://api-@@.sendbird.com".replacingOccurrences(of: "@@", with: appId)
#endif
    }
    
    static func wsHostURL(for appId: String) -> String {
        let pref = SendbirdAuth.pref
        if let customWsHost: String = pref.value(forKey: PreferenceKey.customWsHost) {
            return customWsHost
        }
        
#if TESTCASE
        guard let host = (Bundle(for: SendbirdAuth.self).infoDictionary?["WS_HOST_URL"] as? String)?.replacingOccurrences(of: "@@", with: appId) else {
            assertionFailure("unresolved ws host!")
            return ""
        }
        return host
#else
        return "wss://ws-@@.sendbird.com".replacingOccurrences(of: "@@", with: appId)
#endif
    }
    
    static func baseHostURL(for appId: String) -> String? {
#if TESTCASE
        return (Bundle(for: SendbirdAuth.self).infoDictionary?["BASE_HOST_URL"] as? String)?.replacingOccurrences(of: "@@", with: appId)
#else
        return "api-@@.sendbird.com".replacingOccurrences(of: "@@", with: appId)
#endif
    }
}
