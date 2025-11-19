//
//  Logger.Observer.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/08/20.
//

import Foundation

protocol LoggerObserver: AnyObject {
    var identifier: String { get }
    
    var limit: Logger.Level { get set }
    
    var categories: Logger.Categories { get set }
    
    var receivers: [WeakReference<SBLogReceiver>] { get set }
    
    func log(message: String)
}

extension LoggerObserver {
    func add(receiver: SBLogReceiver) {
        if self.receivers.contains(where: { $0.value === receiver }) == true { return }
        self.receivers.append(WeakReference(value: receiver))
    }
    
    func remove(receiver: SBLogReceiver) {
        self.receivers.removeAll { $0.value === receiver }
    }
}

extension LoggerObserver {
    func log(message: String) {
        self.receivers
            .compactMap { $0.value }
            .forEach { $0.log(message: message) }
    }
}

extension Logger {
    class ObserverInfo {
        weak var observer: LoggerObserver?
        
        init(observer: LoggerObserver) {
            self.observer = observer
        }
    }
}
