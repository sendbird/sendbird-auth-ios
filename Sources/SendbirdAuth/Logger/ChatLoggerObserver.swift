//
//  ChatLogger.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/20.
//

import Foundation

@objc
protocol SBLogReceiver: AnyObject {
    @objc(logMessage:)
    func log(message: String)
}

@objc
class ChatLoggerObserver: NSObject, LoggerObserver {
    var identifier: String = "com.sendbird.core.logger.default"
    
    var limit: Logger.Level
    var categories: Logger.Categories // for SDK Developers.
    
    var receivers = [WeakReference<SBLogReceiver>]()
    private let consoleReceiver = ConsoleReceiver()
    #if INSPECTION
    private let inspectionReceiver = InspectionReceiver()
    #endif
    
    override init() {
        #if DEBUG
        self.limit = .verbose
        self.categories = .all
        #else
        self.limit = .none
        self.categories = .all
        #endif
        
        super.init()
        
        add(receiver: consoleReceiver)
        #if INSPECTION
        add(receiver: inspectionReceiver)
        #endif
    }
}

/**
 logger for IDE Console.
 */
class ConsoleReceiver: SBLogReceiver {
    let queue = DispatchQueue(label: "com.sendbird.core.logger_\(UUID().uuidString)")
    
    func log(message: String) {
        queue.async { print(message) }
    }
}
