//
//  InternalInitParams.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/19/25.
//

import Foundation

package class InternalInitParams: NSObject {
    /// Application ID
    package var applicationId: String
    
    /// Determines to use local caching
    package var isLocalCachingEnabled: Bool
    
    /// Loglevel
    package var logLevel: AuthLogLevel = .none
    
    /// Host app version
    package var appVersion: String?
    
    package var customAPIHost: String?
    package var customWSHost: String?

    package init(
        applicationId: String,
        isLocalCachingEnabled: Bool,
        logLevel: AuthLogLevel = .none,
        appVersion: String? = nil
    ) {
        self.applicationId = applicationId
        self.isLocalCachingEnabled = isLocalCachingEnabled
        self.logLevel = logLevel
        self.appVersion = appVersion
    }
    
    package override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? InternalInitParams else { return false }
        
        return applicationId == object.applicationId
        && isLocalCachingEnabled == object.isLocalCachingEnabled
        && customAPIHost == object.customAPIHost
        && customWSHost == object.customWSHost
    }
}
