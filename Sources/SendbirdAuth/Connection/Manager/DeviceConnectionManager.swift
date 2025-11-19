//
//  DeviceConnectionManager.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

package class DeviceConnectionManager {
    @InternalAtomic package var broadcaster: ConnectionEventBroadcaster
    @InternalAtomic package var internalBroadcaster: InternalConnectionEventBroadcaster
    @InternalAtomic package var networkBroadcaster: NetworkEventBroadcaster
    
    @InternalAtomic package var reachability: Reachability?
    
    package var isOnline: Bool { !isOffline }
    package var isOffline: Bool { networkConnection == .unavailable }
    package var networkConnection: Reachability.Connection = .unavailable {
        didSet {
            webSocketManager?.changeNetworkStatus(to: networkConnection)
        }
    }
    
    package var useReachability: Bool = true
    package var isReachabilityRunning: Bool {
        reachability?.notifierRunning ?? false
    }
    
    package private(set) var isForeground: Bool = true
    private var currentHost: String = ""
    
    package weak var sessionManager: SessionManager?
    package weak var webSocketManager: WebSocketManager? {
        didSet {
            webSocketManager?.changeNetworkStatus(to: networkConnection)
        }
    }
    
    package var hasSessionDelegate: Bool {
        sessionManager?.sessionHandler.delegate(forKey: DelegateKeys.session) != nil
    }
    
    private let eventDispatcher: EventDispatcher
    private let timerBoard: SBTimerBoard
    
    package init(
        commandRouter: CommandRouter?,
        sessionManager: SessionManager?,
        eventDispatcher: EventDispatcher,
        broadcaster: ConnectionEventBroadcaster,
        networkBroadcaster: NetworkEventBroadcaster,
        internalBroadcaster: InternalConnectionEventBroadcaster
    ) {
        self.broadcaster = broadcaster
        self.networkBroadcaster = networkBroadcaster
        self.internalBroadcaster = internalBroadcaster
        self.eventDispatcher = eventDispatcher
        
        timerBoard = SBTimerBoard(capacity: 1)
        webSocketManager = commandRouter?.webSocketManager
        self.sessionManager = sessionManager
        
#if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enteredForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enteredBackgroundWithoutCompletion),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
#elseif os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enteredForeground),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(enteredBackgroundWithoutCompletion),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
#endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    package func logout() {
        timerBoard.stopAll()
        stopReachability()
    }
}

extension DeviceConnectionManager {
    @objc
    package func enteredForeground() {
        Logger.external.info("Entered foreground.")
        isForeground = true
        
        let willReconnect = sessionManager?.reconnect(reconnectedBy: .enteringForeground)
        if willReconnect == false {
            refreshForFeed()
        }
    }
    
    @objc
    private func enteredBackgroundWithoutCompletion() {
        enteredBackground(completion: nil)
    }
    
    package func enteredBackground(completion: VoidHandler?) {
        Logger.external.info("Entered background.")
        
        isForeground = false
        webSocketManager?.enterBackground(completionHandler: completion)
    }
    
    @objc
    package func willTerminate() {
        eventDispatcher.dispatch(command: ApplicationStateEvent.Terminate())
    }
    
    @discardableResult
    package func startReachability(host: String? = nil) -> Bool {
        guard let applicationId = webSocketManager?.stateData?.applicationId else {
            return false
        }
        
        let destination = host ?? Configuration.apiHostURL(for: applicationId)
        
        let isDifferentHost = (currentHost != destination)
        
        guard isDifferentHost || isReachabilityRunning == false else {
            return false
        }
        
        currentHost = destination
        stopReachability()
        
        Logger.main.verbose("Run the network reachability.")
        guard let hostname = URL(string: destination)?.host else { return false }
        
        if let reachability = try? Reachability(hostname: hostname) {
            reachability.whenReachabilityChanged = { [weak self] reachability in
                self?.handleReachabilityChange(to: reachability.connection)
            }
            
            try? reachability.startNotifier()
            self.reachability = reachability
            networkConnection = reachability.connection
            Logger.main.verbose("Current reachable network interface: \(networkConnection.description)")
            return true
        }
        return false
    }
    
    package func restartReachability() {
        Logger.main.verbose("Restart the network reachability.")
        let host = currentHost
        
        stopReachability()
        startReachability(host: host)
    }
    
    package func stopReachability() {
        reachability?.stopNotifier()
    }
    
    private func handleReachabilityChange(to newConnection: Reachability.Connection) {
        guard useReachability else { return }
        
        if networkConnection != newConnection, newConnection.isAvailable {
            let willReconnect = sessionManager?.reconnect(reconnectedBy: .networkReachability)
            if willReconnect == false {
                refreshForFeed()
            }
        }
        
        networkConnection = newConnection
    }
    
    package func refreshForFeed() {
        guard let session = sessionManager?.session,
              session.services.count == 1,
              session.services.contains(.feed) else { return }
        
        let authRefresh = AuthenticationStateEvent.Refresh()
        sessionManager?.router.eventDispatcher.dispatch(command: authRefresh)
    }
}

extension DeviceConnectionManager: EventDelegate {
    package func didReceiveSBCommandEvent(command _: SBCommand) async {
        // do-nothing
    }
    
    package func didReceiveInternalEvent(command: InternalEvent) {
        switch command {
        case let command as ConnectionStateEvent.Connected:
            if command.isReconnected {
                if networkConnection == .unavailable && webSocketManager?.state.reconnectedBy != .networkReachability {
                    restartReachability()
                }
                broadcaster.succeededReconnection()
                networkBroadcaster.reconnected()
            } else {
                if let userId = command.loginEvent.user?.userId {
                    broadcaster.connected(userId: userId)
                }
            }
            
        case let command as ConnectionStateEvent.Logout:
            broadcaster.disconnected(userId: command.userId)
            
        case _ as ConnectionStateEvent.InternalDisconnected:
            internalBroadcaster.internalDisconnected()
            
        case _ as ConnectionStateEvent.ExternalDisconnected:
            internalBroadcaster.externalDisconnected()
            
        case is ConnectionStateEvent.ReconnectingStarted:
            broadcaster.startedReconnection()
            
        case is ConnectionStateEvent.ReconnectionFailed:
            broadcaster.failedReconnection()
            
        case is ConnectionStateEvent.ReconnectionCanceled:
            break
            
        case let command as ConnectionStateEvent.ConnectionDelayed:
            broadcaster.delayedConnection(retryAfter: command.retryAfter)
            
        default: break
        }
    }
}

#if TESTCASE
package extension DeviceConnectionManager {
    var isReachabilityRunningForTest: Bool {
        isReachabilityRunning
    }

    func setNetworkConnectionForTest(_ connection: Reachability.Connection) {
        networkConnection = connection
    }

    func simulateReachabilityChangeForTest(to connection: Reachability.Connection) {
        guard let reachability else { return }

        // Update the flags to match the desired connection state
        switch connection {
        case .unavailable:
            reachability.flags = .connectionRequired
        case .wifi, .cellular:
            reachability.flags = .reachable
        }
        
        // Notify about the reachability change
        reachability.whenReachabilityChanged?(reachability)
    }
}
#endif
