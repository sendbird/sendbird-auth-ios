//
//  InternalInitParams.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/19/25.
//

import Foundation

public class InternalInitParams: NSObject {
    /// Application ID
    public var applicationId: String
    
    /// Determines to use local caching
    public var isLocalCachingEnabled: Bool
    
    /// Loglevel
    public var logLevel: AuthLogLevel = .none
    
    /// Host app version
    public var appVersion: String?
    
    public var customAPIHost: String?
    public var customWSHost: String?

    public init(
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
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? InternalInitParams else { return false }
        
        return applicationId == object.applicationId
        && isLocalCachingEnabled == object.isLocalCachingEnabled
        && customAPIHost == object.customAPIHost
        && customWSHost == object.customWSHost
    }
}
