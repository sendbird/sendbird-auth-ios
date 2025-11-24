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

public class DeviceConnectionManager {
    @InternalAtomic public var broadcaster: ConnectionEventBroadcaster
    @InternalAtomic public var internalBroadcaster: InternalConnectionEventBroadcaster
    @InternalAtomic public var networkBroadcaster: NetworkEventBroadcaster
    
    @InternalAtomic public var reachability: Reachability?
    
    public var isOnline: Bool { !isOffline }
    public var isOffline: Bool { networkConnection == .unavailable }
    public var networkConnection: Reachability.Connection = .unavailable {
        didSet {
            webSocketManager?.changeNetworkStatus(to: networkConnection)
        }
    }
    
    public var useReachability: Bool = true
    public var isReachabilityRunning: Bool {
        reachability?.notifierRunning ?? false
    }
    
    public private(set) var isForeground: Bool = true
    private var currentHost: String = ""
    
    public weak var sessionManager: SessionManager?
    public weak var webSocketManager: WebSocketManager? {
        didSet {
            webSocketManager?.changeNetworkStatus(to: networkConnection)
        }
    }
    
    public var hasSessionDelegate: Bool {
        sessionManager?.sessionHandler.delegate(forKey: DelegateKeys.session) != nil
    }
    
    private let eventDispatcher: EventDispatcher
    private let timerBoard: SBTimerBoard
    
    public init(
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
    
    public func logout() {
        timerBoard.stopAll()
        stopReachability()
    }
}

extension DeviceConnectionManager {
    @objc
    public func enteredForeground() {
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
    
    public func enteredBackground(completion: VoidHandler?) {
        Logger.external.info("Entered background.")
        
        isForeground = false
        webSocketManager?.enterBackground(completionHandler: completion)
    }
    
    @objc
    public func willTerminate() {
        eventDispatcher.dispatch(command: ApplicationStateEvent.Terminate())
    }
    
    @discardableResult
    public func startReachability(host: String? = nil) -> Bool {
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
    
    public func restartReachability() {
        Logger.main.verbose("Restart the network reachability.")
        let host = currentHost
        
        stopReachability()
        startReachability(host: host)
    }
    
    public func stopReachability() {
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
    
    public func refreshForFeed() {
        guard let session = sessionManager?.session,
              session.services.count == 1,
              session.services.contains(.feed) else { return }
        
        let authRefresh = AuthenticationStateEvent.Refresh()
        sessionManager?.router.eventDispatcher.dispatch(command: authRefresh)
    }
}

extension DeviceConnectionManager: EventDelegate {
    public func didReceiveSBCommandEvent(command _: SBCommand) async {
        // do-nothing
    }
    
    public func didReceiveInternalEvent(command: InternalEvent) {
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
public extension DeviceConnectionManager {
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
