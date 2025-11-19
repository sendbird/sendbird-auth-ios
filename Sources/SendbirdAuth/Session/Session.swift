//
//  Session.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2023/07/11.
//

import Foundation

package struct Session: Codable, Equatable, Comparable {
    package init(key: String, services: [Session.Service], isDirty: Bool = false) {
        self.key = key
        self.services = services
        self.isDirty = isDirty
    }
    
    package struct Constants {
        package static let sessionKeyPath = "com.sendbird.sdk.messaging.sessionkey"
        package static let userIdKeyPath = "com.sendbird.sdk.messaging.userid"
        package static let suiteName = "com.sendbird.sdk.manager.session"
        package static let queueName = "com.sendbird.sdk.messaging.sessionKey.queue"
    }
    
    // Service value that is used to control the API scope that is accessible via the session key
    // Refer to https://sendbird.atlassian.net/wiki/spaces/SDK/pages/2376695899/Extended+MAU
    package enum Service: String, Codable {
        case feed
        case chat
        case chatAPI = "chat_api"
        
        package var intValue: Int {
            switch self {
            case .feed: return 1
            case .chat: return 2
            case .chatAPI: return 3
            }
        }
    }
    
    package let key: String
    package let services: [Service]
    package let isDirty: Bool
    
    package init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodeCodingKeys.self)
        self.key = try container.decode(String.self, forKey: .key)
        self.services = try container.decode([Service].self, forKey: .services)
        self.isDirty = false
    }
    
    package static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.key == rhs.key && lhs.services == rhs.services
    }
    
    package static func < (lhs: Session, rhs: Session) -> Bool {
        return lhs.services.map { $0.intValue }.reduce(0, +) < rhs.services.map { $0.intValue }.reduce(0, +)
    }
    
    package func isLargerScope(than other: Session) -> Bool {
        return self > other
    }
}

extension Session {
    package static func buildFromUserDefaults(for userId: String? = nil) -> Self? {
        guard let userDefault = UserDefaults(suiteName: Constants.suiteName),
              let encryptedUserId = userDefault.string(forKey: Constants.userIdKeyPath) else {
            Logger.session.verbose(" failed with no saved encrypted user Id")
            return nil
        }
        
        if let userId, let existingUserEncryption = userId.data(using: .utf8)?.base64EncodedString(),
           existingUserEncryption != encryptedUserId {
            Self.clearUserDefaults()
            return nil
        }
        
        let prefixUserId = encryptedUserId.prefix(10)
        let decryptionSeed = String(prefixUserId)
        let encryptedSessionData = userDefault.data(forKey: Constants.sessionKeyPath)
        
        guard let decryptedSessionData = encryptedSessionData?.aes256DecryptedData(with: decryptionSeed) else {
            return nil
        }
        
        if let session = try? JSONDecoder().decode(Session.self, from: decryptedSessionData) {
            // If Session was encrypted
            return Session(key: session.key, services: session.services, isDirty: true)
        } else if let sessionKey = String(data: decryptedSessionData, encoding: .utf8) {
            // If older version encrypted only session key
            return Session(key: sessionKey, services: [.feed, .chat], isDirty: true)
        } else {
            return nil
        }
        
    }
    
    package static func saveToUserDefaults(session: Session, userId: String?) {
        guard let userDefaults = UserDefaults(suiteName: Constants.suiteName) else {
            Logger.session.verbose(" failed with invalid user defaults suite")
            return
        }
        
        guard let data = userId?.data(using: .utf8) else {
            Logger.session.verbose(" failed with no current user Id")
            return
        }
        
        let based64UserId = data.base64EncodedString()
        userDefaults.set(based64UserId, forKey: Constants.userIdKeyPath)
        
        let prefixUserId = based64UserId.prefix(10)
        let shortEncodedUserId = String(prefixUserId)
        
        guard let encodedSession = try? JSONEncoder().encode(session) else {
            Logger.session.verbose(" failed to save session infromation due to invalid type")
            return
        }
        
        let encryptedData = encodedSession.aes256EncryptedData(with: shortEncodedUserId)
        userDefaults.set(encryptedData, forKey: Constants.sessionKeyPath)
    }
    
    package static func clearUserDefaults() {
        guard let userDefaults = UserDefaults(suiteName: Constants.suiteName) else {
            Logger.session.verbose(" failed with invalid user defaults suite")
            return
        }

        userDefaults.removeObject(forKey: Constants.userIdKeyPath)
        userDefaults.removeObject(forKey: Constants.sessionKeyPath)
    }
}
