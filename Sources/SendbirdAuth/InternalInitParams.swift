//
//  InternalInitParams.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/19/25.
//

import Foundation

@_spi(SendbirdInternal) public class InternalInitParams: NSObject {
    /// Application ID
    @_spi(SendbirdInternal) public var applicationId: String
    
    /// Determines to use local caching
    @_spi(SendbirdInternal) public var isLocalCachingEnabled: Bool
    
    /// Loglevel
    @_spi(SendbirdInternal) public var logLevel: AuthLogLevel = .none
    
    /// Host app version
    @_spi(SendbirdInternal) public var appVersion: String?
    
    @_spi(SendbirdInternal) public var customAPIHost: String?
    @_spi(SendbirdInternal) public var customWSHost: String?

    @_spi(SendbirdInternal) public var hostBundle: Bundle?

    @_spi(SendbirdInternal) public var mainSDKInfo: SendbirdSDKInfo?

    /// Custom exception parser for API error responses.
    /// Default is `DefaultExceptionParser` which parses Chat API format.
    @_spi(SendbirdInternal) public var exceptionParser: ApiExceptionParser = DefaultExceptionParser()

    /// Session provider for sharing session across multiple SDK instances.
    @_spi(SendbirdInternal) public var sessionProvider: SessionProvider?

    /// Header interceptor for overriding header names and injecting additional headers.
    @_spi(SendbirdInternal) public var headerInterceptor: APIHeaderInterceptor?

    @_spi(SendbirdInternal) public init(
        applicationId: String,
        isLocalCachingEnabled: Bool,
        logLevel: AuthLogLevel = .none,
        appVersion: String? = nil,
        mainSDKInfo: SendbirdSDKInfo? = nil,
        exceptionParser: ApiExceptionParser = DefaultExceptionParser(),
        sessionProvider: SessionProvider? = nil
    ) {
        self.applicationId = applicationId
        self.isLocalCachingEnabled = isLocalCachingEnabled
        self.logLevel = logLevel
        self.appVersion = appVersion
        self.mainSDKInfo = mainSDKInfo
        self.exceptionParser = exceptionParser
        self.sessionProvider = sessionProvider
    }
    
    @_spi(SendbirdInternal) public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? InternalInitParams else { return false }
        
        return applicationId == object.applicationId
        && isLocalCachingEnabled == object.isLocalCachingEnabled
        && customAPIHost == object.customAPIHost
        && customWSHost == object.customWSHost
    }
}
