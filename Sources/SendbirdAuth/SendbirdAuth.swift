//
//  SendbirdAuth 2.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/23/25.
//

import Foundation

package final class SendbirdAuth {
    package static let authDecoder = JSONDecoder()
    
    package static var sdkVersion: String { "4.33.0" }
    
    private static var sdkInstance: SendbirdAuthMain?
    package static func updateSharedSDKInstance(to newMain: SendbirdAuthMain) {
        sdkInstance = newMain
    }
    
    package static var pref = LocalPreferences(suiteName: "com.sendbird.sdk.ios")
    
    package static var isInitialized: Bool {
        guard let sdkInstance else {
            return false
        }
        
        let emptyAppId = sdkInstance.applicationId.isEmpty
        if emptyAppId {
            // TODO: update warning message.
            let warningMessage = "SendbirdAuth [\(Date.now)] 🚨SendbirdAuth instance hasn't been initialized.🚨"
            print(warningMessage)
        }
        return !emptyAppId
    }
    
    package static var isInitializedWithoutWarning: Bool {
        guard let sdkInstance else {
            return false
        }
        
        let emptyAppId = sdkInstance.applicationId.isEmpty
        return !emptyAppId
    }
}
