//
//  AuthInstanceIdentifier.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 3/6/26.
//

import Foundation

/// Encapsulates the information needed to identify a SendbirdAuthMain instance in the registry.
/// If the set of identifying fields changes in the future, only this type needs to be updated.
@_spi(SendbirdInternal) public struct AuthInstanceIdentifier {
    public let appId: String
    public let apiHostUrl: String?

    public init(appId: String, apiHostUrl: String? = nil) {
        self.appId = appId
        self.apiHostUrl = apiHostUrl
    }
}
