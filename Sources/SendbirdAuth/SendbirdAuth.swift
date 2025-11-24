//
//  SendbirdAuth 2.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/23/25.
//

import Foundation

public final class SendbirdAuth {
    public static let authDecoder = JSONDecoder()
    
    public static var sdkVersion: String { "4.34.0" }
    
    private static var sdkInstance: SendbirdAuthMain?
    public static func updateSharedSDKInstance(to newMain: SendbirdAuthMain) {
        sdkInstance = newMain
    }
    
    public static var pref = LocalPreferences(suiteName: "com.sendbird.sdk.ios")
    
    public static var isInitialized: Bool {
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
    
    public static var isInitializedWithoutWarning: Bool {
        guard let sdkInstance else {
            return false
        }
        
        let emptyAppId = sdkInstance.applicationId.isEmpty
        return !emptyAppId
    }
}
