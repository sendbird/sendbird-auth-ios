//
//  EventBroadcaster.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/14.
//

import Foundation

package protocol EventBroadcaster<DelegateType> {
    associatedtype DelegateType: AnyObject
    
    var delegates: NSMapTable<NSString, DelegateType> { get }
    var service: QueueService { get }
    
    func delegate(forKey key: String) -> DelegateType?
    
    func addDelegate(_ delegate: DelegateType, forKey key: String)
    
    func removeDelegate(forKey key: String)
    
    func removeAllDelegates()
    
    func callAsFunction(task: @escaping ((DelegateType) -> Void))
    
    func broadcast<OtherType>(upcast: OtherType, task: @escaping ((OtherType) -> Void))
    
    func broadcast(task: @escaping ((DelegateType) -> Void))
}

extension EventBroadcaster {
    package func delegate(forKey key: String) -> DelegateType? {
        return delegates.object(forKey: key as NSString)
    }
    
    package func addDelegate(_ delegate: DelegateType, forKey key: String) {
        delegates.setObject(delegate, forKey: key as NSString)
    }
    
    package func removeDelegate(forKey key: String) {
        delegates.removeObject(forKey: key as NSString)
    }
    
    package func removeAllDelegates() {
        delegates.removeAllObjects()
    }
    
    package func callAsFunction(task: @escaping ((DelegateType) -> Void)) {
        self.broadcast(task: task)
    }
    
    package func broadcast<OtherType>(upcast: OtherType, task: @escaping ((OtherType) -> Void)) {
        service {
            self.delegates
                .objectEnumerator()?
                .compactMap { $0 as? OtherType }
                .forEach { task($0) }
        }
    }
    
    package func broadcast(task: @escaping ((DelegateType) -> Void)) {
        service {
            let allObjects = delegates.objectEnumerator()?.allObjects
            let allDelegates = (allObjects as? [DelegateType]) ?? []
            
            allDelegates.forEach { task($0) }
        }
    }
}
