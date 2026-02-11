//
//  Configuration.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

import Foundation

extension Configuration {
    struct HostEnvironments {
        let apiHost: String
        let wsHost: String
        
        init(
            applicationId: String,
            customAPIHost: String? = nil,
            customWSHost: String? = nil
        ) {
            if let apiHost = customAPIHost, apiHost.hasElements {
                self.apiHost = apiHost
            } else {
                self.apiHost = Configuration.apiHostURL(for: applicationId)
            }
            
            if let wsHost = customWSHost, wsHost.hasElements {
                self.wsHost = wsHost
            } else {
                self.wsHost = Configuration.wsHostURL(for: applicationId)
            }
        }
    }
}

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

    static func apiHostURL(for appId: String) -> String {
        let template = hostURL(for: "API_HOST_URL", default: defaultAPIHost)
        return template.replacingOccurrences(of: "@@", with: appId)
    }

    static func wsHostURL(for appId: String) -> String {
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
    @available(*, deprecated, message: "Use updateCustomHost(apiHost:wsHost:) instead")
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
    @available(*, deprecated, message: "Use updateCustomHost(apiHost:wsHost:) instead")
    func setCustomHost(_ environment: CustomHostEnvironment) {
        routerConfig.updateHost(apiHost: environment.apiHost, wsHost: environment.wsHost)
    }

    /// Clears custom host and reverts to default hosts based on applicationId.
    func clearCustomHost() {
        guard applicationId.hasElements else {
            Logger.main.error("clearCustomHost() called before initialization")
            return
        }
        let host = Configuration.HostEnvironments(applicationId: applicationId)
        routerConfig.updateHost(apiHost: host.apiHost, wsHost: host.wsHost)
    }

    /// Updates custom host URLs dynamically after initialization.
    /// - Parameters:
    ///   - apiHost: Custom API host URL (e.g., "https://api-no3.sendbirdtest.com")
    ///   - wsHost: Custom WebSocket host URL (e.g., "wss://ws-no3.sendbirdtest.com")
    /// - Note: Should be called before connect/authenticate. If already connected, operation is aborted.
    func updateCustomHost(apiHost: String, wsHost: String) {
        if router.connected {
            Logger.main.error("updateCustomHost() called while already connected. Operation aborted.")
            return
        }
        
        let host = Configuration.HostEnvironments.init(
            applicationId: self.applicationId,
            customAPIHost: apiHost,
            customWSHost: wsHost
        )
        routerConfig.updateHost(apiHost: host.apiHost, wsHost: host.wsHost)
    }
}
