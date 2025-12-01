//
//  StatManager.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/05/30.
//

import Foundation

#if DEBUG
@_spi(SendbirdInternal) public protocol StatManagerInternalDelegate: AnyObject {
    func statManager(_ statManager: StatManager, didChangeState state: StatManager.State)
    func statManager(_ statManager: StatManager, didSendStats result: Result<[any BaseStatType], AuthError>)
    func statManager(_ statManager: StatManager, appendStat stat: any BaseStatType)
    func statManager(_ statManager: StatManager, didSendStatsThrough collector: (any StatCollectorContract)?)
}
#endif

/// An instance that manages the stat collectors for each stat types.
/// - Since: 4.18.0
@_spi(SendbirdInternal) public final class StatManager: Injectable {
    /// The enum that represents the state of the stat manager
    @_spi(SendbirdInternal) public enum State {
        /// Initial state
        case pending
        /// The state that the stat manager is able to collect and upload the stats
        case enabled
        /// The state that the stat manager is able to collect stat logs only
        case collectOnly
        /// The state that the stat manage is disabled.
        case disabled
        
        /// Represents whether the stat manager can append stat logs or not.
        @_spi(SendbirdInternal) public var isAppendable: Bool {
            switch self {
            case .pending, .collectOnly, .enabled:
                return true
            case .disabled:
                return false
            }
        }
        
        /// Represents whether the stat manager can upload the appended stat logs or not.
        @_spi(SendbirdInternal) public var isUploadable: Bool {
            switch self {
            case .enabled:
                return true
            case .pending, .collectOnly, .disabled:
                return false
            }
        }
    }

    /// The enum that represents the stat type for each stat config.
    ///
    /// - Since: 4.18.0
    @_spi(SendbirdInternal) public enum StatConfigType: String {
        case `default` = "default"
        case daily = "daily"
        case notification = "notification"
    }

    /// Default config for the default stat collector
    @_spi(SendbirdInternal) public static let defaultConfig = StatConfig(
        minStatCount: 100,
        minInterval: 3 * 60 * 60, // 3 hours
        maxStatCountPerRequest: 1000,
        lowerThreshold: 10,
        requestDelayRange: 3 * 60 // 3 minutes
    )
    
    /// Default config for the notification stat collector
    @_spi(SendbirdInternal) public static let notificationConfig = StatConfig(
        minStatCount: 1,
        minInterval: 0,
        maxStatCountPerRequest: 1000,
        lowerThreshold: 0,
        requestDelayRange: 20
    )
    
    /// Default config for the daily stat collector
    /// INFO: The stat config for the daily stat is not controller by the server.
    @_spi(SendbirdInternal) public static let dailyStatConfig = StatConfig(
        minStatCount: 0,
        minInterval: 0,
        maxStatCountPerRequest: 1000,
        lowerThreshold: 0,
        requestDelayRange: 180
    )
    
    #if DEBUG
    @_spi(SendbirdInternal) public var defaultConfigForTest: StatConfig?
    #endif
    
    @_spi(SendbirdInternal) public private(set) var apiClient: StatAPIClientable
    
    /// The state of the stat manager
    @_spi(SendbirdInternal) public private(set) var state: State
    
    /// The stat types that will be collected.
    /// This value is updated when LOGI command is received.
    @_spi(SendbirdInternal) public var allowedStatTypes = Set<StatType>()
    
    /// A dictionary to have the stat collectors by the stat type.
    /// - Since: 4.18.0
    @_spi(SendbirdInternal) public var collectors: [StatConfigType: any StatCollectorContract] = [:]
    
    @_spi(SendbirdInternal) public var dailyStatCollector: DailyStatCollector? {
        self.collectors[StatConfigType.daily] as? DailyStatCollector
    }
    @_spi(SendbirdInternal) public var defaultStatCollector: DefaultStatCollector? {
        self.collectors[StatConfigType.default] as? DefaultStatCollector
    }
    @_spi(SendbirdInternal) public var notificationStatCollector: NotificationStatCollector? {
        self.collectors[StatConfigType.notification] as? NotificationStatCollector
    }

    @_spi(SendbirdInternal) public let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.sendbird.core.stat_manager.\(UUID().uuidString)"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        return queue
    }()
    
    private var isFlushing: Bool = false
    
    /// The maximum of count for the uploading stat logs.
    ///
    /// - Since: 4.18.0
    @_spi(SendbirdInternal) public static let maxRetryCount: Int = 20
    
    /// The retry count for the uploading stat logs.
    /// The count will be increased when the uploading is failed.
    /// When the count reaches the `maxRetryCount`,
    /// the state of the stat manager changes to the `collectOnly`.
    ///
    /// - Since: 4.18.0
    @_spi(SendbirdInternal) public var retryCount: Int = 0
    
    @DependencyWrapper private var dependency: Dependency?
    /// A flag that represents the local caching is enabled or not.
    /// This property is set when the stat manager is initialized.
    /// When the stat manager appends the `LocalCacheStat` after the LOGI is received, this value is used.
    /// - Since: 4.18.0
    @_spi(SendbirdInternal) public var isLocalCachingEnabled: Bool
    
    /// - Since: 4.22.1
    private var connectionStartedAt: Int64? { // ms, (stat 수집 과정에서 데이터 오염이 발생할 수 있으면 nil 처리)
        didSet {
            #if DEBUG
            if connectionStartedAt != nil {
                connectionStartedAtForTest = connectionStartedAt
            }
            #endif
        }
    }
    @_spi(SendbirdInternal) public private(set) var wsOpenedEvent: WebSocketStatEvent.WebSocketOpenedEvent? {
        didSet {
            #if DEBUG
            if wsOpenedEvent != nil {
                wsOpenedEventForTest = wsOpenedEvent
            }
            #endif
        }
    }
    
    /// A flag that is true if SDK received a `BUSY` command at least once.
    /// If this falg is true, when sending the `WebSocketConnectStat`, `isSoftRateLimited` should be `true`.
    /// - Since: 4.34.0
    private var hasReceivedBUSYatLeastOnce: Bool = false
    
    #if DEBUG
    @_spi(SendbirdInternal) public var connectionStartedAtForTest: Int64?
    @_spi(SendbirdInternal) public private(set) var wsOpenedEventForTest: WebSocketStatEvent.WebSocketOpenedEvent?
    #endif
    
    @_spi(SendbirdInternal) public var connectionRetryCount: Int = 0
    @_spi(SendbirdInternal) public var reconnectionTryCount: Int = 0
    @_spi(SendbirdInternal) public var connectionId: String?
    @_spi(SendbirdInternal) public var accumulatedTrialCount: Int {
        // If the SDK has connected with `ReconnectingState`,
        // the `accumulatedTrialCount` should use the `reconnectionTryCount`
        if reconnectionTryCount > 0 {
            return reconnectionTryCount
        } else {
            return 1 + connectionRetryCount
        }
    }
    
    private let configuration: SendbirdConfiguration
    
    @_spi(SendbirdInternal) public init(
        apiClient: StatAPIClientable,
        isLocalCachingEnabled: Bool,
        configuration: SendbirdConfiguration
    ) {
        self.apiClient = apiClient
        self.isLocalCachingEnabled = isLocalCachingEnabled
        self.configuration = configuration
        
        self.state = .pending
        self.allowedStatTypes = Set(StatType.allCases)
        self.retryCount = Self.maxRetryCount

        self.collectors[.daily] = DailyStatCollector(
            statConfig: Self.dailyStatConfig,
            apiClient: apiClient,
            userDefaults: Self.baseStorage,
            delegate: self,
            enabled: true
        )
        
        self.collectors[.default] = DefaultStatCollector(
            statConfig: Self.defaultConfig,
            apiClient: self.apiClient,
            userDefaults: Self.baseStorage,
            delegate: self,
            enabled: true
        )
        
        self.collectors[.notification] = NotificationStatCollector(
            statConfig: Self.notificationConfig,
            apiClient: self.apiClient,
            userDefaults: Self.baseStorage,
            delegate: self,
            enabled: false
        )
        
        self.apiClient.setDeviceId(deviceId: self.getDeviceId())
    }
    
    /// Appends the stat to the proper stat collector.
    /// - Parameters:
    ///   - stat: The stat to be appended
    ///   - completion: The callback to be executed
    @_spi(SendbirdInternal) public func append<RecordStatType>(_ stat: RecordStatType, fromAuth: Bool? = nil, completion: VoidHandler? = nil) where RecordStatType: BaseStatType {
        Logger.main.debug("append stat: \(stat)")
        queue.addOperation { [weak self] in
            Logger.main.debug("appendable state: \(String(describing: self?.state.isAppendable)), allowed: \(String(describing: self?.isAllowed(stat.statType)))")
            guard let self = self,
                  self.state.isAppendable,
                  self.isAllowed(stat.statType) else {
                completion?()
                return
            }
            
            switch stat {
            case let stat as DailyRecordStat:
                self.dailyStatCollector?.appendStat(stat) {
                    #if DEBUG
                    Logger.main.debug("Append stat: \(stat), delegate: \(String(describing: self.delegate))")
                    self.delegate?.statManager(self, appendStat: stat)
                    #endif
                    completion?()
                }
                
            case let stat as NotificationStat:
                self.notificationStatCollector?.appendStat(stat) {
                    #if DEBUG
                    Logger.main.debug("Append stat: \(stat), delegate: \(String(describing: self.delegate))")
                    self.delegate?.statManager(self, appendStat: stat)
                    #endif
                    completion?()
                }
            case let stat as DefaultRecordStat:
                self.defaultStatCollector?.appendStat(stat) {
                    #if DEBUG
                    Logger.main.debug("Append stat: \(stat), delegate: \(String(describing: self.delegate))")
                    self.delegate?.statManager(self, appendStat: stat)
                    #endif
                    completion?()
                }
                
            case let stat as any DailyRecordStatType:
                self.dailyStatCollector?.appendStat(stat.toDailyRecordStat()) {
                    #if DEBUG
                    Logger.main.debug("Append stat: \(stat), delegate: \(String(describing: self.delegate))")
                    self.delegate?.statManager(self, appendStat: stat)
                    #endif
                    completion?()
                }
                
            case let stat as any DefaultRecordStatRepresentable:
                self.defaultStatCollector?.appendStat(stat.toDefaultRecordStat()) {
                    #if DEBUG
                    Logger.main.debug("Append stat: \(stat), delegate: \(String(describing: self.delegate))")
                    self.delegate?.statManager(self, appendStat: stat)
                    #endif
                    completion?()
                }
                
            default:
                completion?()
            }
        }
    }
    
    /// [Improve WebSocket latency stat collect](https://sendbird.atlassian.net/wiki/spaces/SDK/pages/2552136079/Improve+WebSocket+latency+stat+collect)
    ///
    /// ** Connect req - (1) -> Opened - (2) -> LOGI (3)  -> Connected**
    /// - Connect req: connec / reconnect req
    /// - opened: WebSocket opened
    /// - LOGI: connectedState
    ///
    /// (1)
    /// - `latency`: currentTS - requestSentTS (currentTS 는 failed 시점의 TS)
    /// - `logi_latency` :null
    /// - `success`: false
    /// (2), (3)
    /// - `latency`: openedTS - requestSentTS
    /// - `logi_latency` :currentTS - requestSentTS
    /// - `success`: true/false (LOGI 결과에 따라)
    
    @_spi(SendbirdInternal) public func append(logiEvent: LoginEvent) {
        // (3) case
        defer { self.restoreWebSocketOpenedEvent() }
        
        guard let connectionStartedAt = connectionStartedAt else { return }
        guard let wsOpenedEvent = wsOpenedEvent else { return }
        
        let (latencyForOpened, latencyForLOGI) = calculateLatencies(connectionStartedAt: connectionStartedAt)
        let success = (logiEvent.hasError != true)
        
        Logger.stat.debug(
            "Appending wsConnect logiEvent. " +
            "connectionStartedAt: \(connectionStartedAt), " +
            "latencyForOpened: \(latencyForOpened), " +
            "latencyForLOGI: \(String(describing: latencyForLOGI)), " +
            "success: \(success)"
        )
        
        if self.isValidLatencyWithTimeout(latencyForOpened, latencyForLOGI) == false {
            return
        }
        
        self.append(
            WebSocketConnectStat(
                latencyInfo: WebSocketLatencyInfo(
                    hostURL: wsOpenedEvent.hostURL,
                    latencyForOpened: latencyForOpened,
                    latencyForLOGI: latencyForLOGI,
                    success: success
                ),
                errorCode: logiEvent.errorCode,
                errorDescription: logiEvent.errorMessage,
                accumulatedTrial: accumulatedTrialCount,
                connectionId: connectionId ?? "",
                isSoftRateLimited: hasReceivedBUSYatLeastOnce
            )
        )
        self.hasReceivedBUSYatLeastOnce = false
    }
    
    private func append(failedEvent: WebSocketStatEvent.WebSocketFailedEvent) {
        defer { self.restoreWebSocketOpenedEvent() }
        guard let connectionStartedAt = connectionStartedAt else { return }

        // (1), (2) case
        let (latencyForOpened, latencyForLOGI) = calculateLatencies(connectionStartedAt: connectionStartedAt)
        
        let hostURL: String = failedEvent.hostURL
        let errorCode: Int? = failedEvent.code
        let errorDescription: String? = failedEvent.reason
        
        Logger.stat.debug(
            "Appending wsConnect failedEvent. " +
            "connectionStartedAt: \(connectionStartedAt), " +
            "latencyForOpened: \(latencyForOpened), " +
            "latencyForLOGI: \(String(describing: latencyForLOGI)), " +
            "errorDesc: \(errorDescription ?? ""), " +
            "success: false"
        )
        
        if self.isValidLatencyWithTimeout(latencyForOpened, latencyForLOGI) == false {
            return
        }
        
        self.append(
            WebSocketConnectStat(
                latencyInfo: WebSocketLatencyInfo(
                    hostURL: hostURL,
                    latencyForOpened: latencyForOpened,
                    latencyForLOGI: latencyForLOGI,
                    success: false
                ),
                errorCode: errorCode,
                errorDescription: errorDescription,
                accumulatedTrial: accumulatedTrialCount,
                connectionId: connectionId ?? "",
                isSoftRateLimited: hasReceivedBUSYatLeastOnce
            )
        )
        self.hasReceivedBUSYatLeastOnce = false
    }
    
    private func append(timeoutEvent: WebSocketStatEvent.WebSocketLoginTimeoutEvent) {
        defer { self.restoreWebSocketOpenedEvent() }
        
        guard let connectionStartedAt = connectionStartedAt else { return }
        
        // (1), (2) case
        let (latencyForOpened, latencyForLOGI) = calculateLatencies(connectionStartedAt: connectionStartedAt)
        
        let hostURL: String = timeoutEvent.hostURL
        let errorCode: Int? = timeoutEvent.error.errorCode?.code
        let errorDescription: String? = timeoutEvent.error.errorCode?.message
        
        Logger.stat.debug(
            "Appending wsConnect timeoutEvent. " +
            "connectionStartedAt: \(connectionStartedAt), " +
            "latencyForOpened: \(latencyForOpened), " +
            "latencyForLOGI: \(String(describing: latencyForLOGI)), " +
            "errorDesc: \(errorDescription ?? ""), " +
            "success: false"
        )
        
        if self.isValidLatencyWithTimeout(latencyForOpened, latencyForLOGI) == false {
            return
        }
        
        self.append(
            WebSocketConnectStat(
                latencyInfo: WebSocketLatencyInfo(
                    hostURL: hostURL,
                    latencyForOpened: latencyForOpened,
                    latencyForLOGI: latencyForLOGI,
                    success: false
                ),
                errorCode: errorCode,
                errorDescription: errorDescription,
                accumulatedTrial: accumulatedTrialCount,
                connectionId: connectionId ?? "",
                isSoftRateLimited: hasReceivedBUSYatLeastOnce
            )
        )
        self.hasReceivedBUSYatLeastOnce = false
    }
    
    private func append(reconnectTimeoutEvent: WebSocketStatEvent.WebSocketReconnectLoginTimeoutEvent) {
        defer { self.restoreWebSocketOpenedEvent() }
        
        guard let connectionStartedAt = connectionStartedAt else { return }
        
        // (1), (2) case
        let (latencyForOpened, latencyForLOGI) = calculateLatencies(connectionStartedAt: connectionStartedAt)
        
        let hostURL: String = reconnectTimeoutEvent.hostURL
        let errorCode: Int? = reconnectTimeoutEvent.error.errorCode?.code
        let errorDescription: String? = reconnectTimeoutEvent.error.errorCode?.message
        
        Logger.stat.debug(
            "Appending wsConnect reconnect timeoutEvent. " +
            "connectionStartedAt: \(connectionStartedAt), " +
            "latencyForOpened: \(latencyForOpened), " +
            "latencyForLOGI: \(String(describing: latencyForLOGI)), " +
            "errorDesc: \(errorDescription ?? ""), " +
            "success: false"
        )
        
        if self.isValidLatencyWithTimeout(latencyForOpened, latencyForLOGI) == false {
            return
        }
        
        self.append(
            WebSocketConnectStat(
                latencyInfo: WebSocketLatencyInfo(
                    hostURL: hostURL,
                    latencyForOpened: latencyForOpened,
                    latencyForLOGI: latencyForLOGI,
                    success: false
                ),
                errorCode: errorCode,
                errorDescription: errorDescription,
                accumulatedTrial: accumulatedTrialCount,
                connectionId: connectionId ?? "",
                isSoftRateLimited: hasReceivedBUSYatLeastOnce
            )
        )
        self.hasReceivedBUSYatLeastOnce = false
    }
    
    /// Append specifically `disconnect` event
    private func append(disconnectEvent: WebSocketStatEvent.WebSocketDisconnectEvent) {
        defer { restoreWebSocketOpenedEvent() }
        
        let errorCode: Int? = disconnectEvent.error?.errorCode?.code
        let errorDescription: String? = disconnectEvent.error?.errorCode?.message
        
        Logger.stat.debug(
            "Appending ws disconnect event. " +
            "errorDesc: \(errorDescription ?? ""), " +
            "cause: \(disconnectEvent.reason), " +
            "success: true"
        )
        
        self.append(
            WebSocketDisconnectedStat(
                success: true,
                errorCode: errorCode ?? 0,
                reason: disconnectEvent.reason
            )
        )
    }
    
    private func calculateLatencies(connectionStartedAt: Int64) -> (latencyForOpened: Int64, latencyForLOGI: Int64?) {
        let now = Date().milliSeconds
        
        if let wsOpenedEvent {
            let openedTimestamp = wsOpenedEvent.openedTimestampMs
            return (openedTimestamp - connectionStartedAt, now - connectionStartedAt)
        } else {
            return (now - connectionStartedAt, nil)
        }
    }
    
    // timeout 시간이 넘는 latency 는 버리기 위한 체크
    @_spi(SendbirdInternal) public func isValidLatencyWithTimeout(_ latencyForOpened: Int64, _ latencyForLOGI: Int64?) -> Bool {
        // Connection timeout: 10s
        let connectionTimeout = Int64(configuration.websocketTimeout) * 1000
        // LOGI response timeout: 10s
        let logiResponseTimeout = Int64(configuration.websocketTimeout) * 1000
        // buffer time: 1.0s
        let bufferTime = Int64(1.0 * 1000)
        
        if latencyForOpened > (connectionTimeout + bufferTime) {
            return false
        }
        if let latencyForLOGI, latencyForLOGI > (logiResponseTimeout + bufferTime) {
            return false
        }
        return true
    }
    
    // webSocketOpenedEvent 관련 객체 초기화
    @_spi(SendbirdInternal) public func restoreWebSocketOpenedEvent() {
        Logger.stat.debug("Appending wsConnect restore wsOpenedEvent.")
        
        self.wsOpenedEvent = nil
        self.connectionStartedAt = nil
    }
    
    @_spi(SendbirdInternal) public func update(allowedStatTypes: Set<StatType>, completion: VoidHandler? = nil) {
        queue.addOperation { [weak self] in
            guard let self = self else {
                return
            }
            self.allowedStatTypes = allowedStatTypes
            self.filterStats()
            completion?()
        }
    }
    
    @_spi(SendbirdInternal) public func enable(completion: VoidHandler? = nil) {
        queue.addOperation { [weak self] in
            defer { completion?() }
            guard let self = self else {
                return
            }

            let fromAuth = self.state == .pending
            
            self.filterStats()
            self.state = .enabled

            self.defaultStatCollector?.trySendStats(fromAuth: fromAuth) {
                #if DEBUG
                self.delegate?.statManager(self, didSendStatsThrough: self.defaultStatCollector)
                #endif
            }
            self.dailyStatCollector?.trySendStats(
                completion: {
                    #if DEBUG
                    self.delegate?.statManager(self, didSendStatsThrough: self.dailyStatCollector)
                    #endif
                }
            )
            self.notificationStatCollector?.trySendStats(
                completion: {
                    #if DEBUG
                    self.delegate?.statManager(self, didSendStatsThrough: self.notificationStatCollector)
                    #endif
                }
            )
            
            #if DEBUG
            self.delegate?.statManager(self, didChangeState: self.state)
            #endif
        }
    }
    
    @_spi(SendbirdInternal) public func changeToCollectOnly() {
        queue.addOperation { [weak self] in
            guard let self = self else {
                return
            }
            self.state = .collectOnly
            #if DEBUG
            self.delegate?.statManager(self, didChangeState: self.state)
            #endif
        }
    }
    
    /// Logout할 때 쌓아둔 로그 삭제
    @_spi(SendbirdInternal) public func disable(completion: VoidHandler? = nil) {
        queue.addOperation { [weak self] in
            defer { completion?() }
            guard let self = self else {
                return
            }
            self.state = .disabled
            self.removeAll()
            #if DEBUG
            self.delegate?.statManager(self, didChangeState: self.state)
            #endif
        }
    }

    /// 수집하기로 한 stat type만 남기고 다른 로그는 전부 삭제함.
    private func filterStats() {
        let disallowedStatTypes = Set(StatType.allCases).subtracting(allowedStatTypes)
        
        dailyStatCollector?.storage.remove(disallowedStatTypes: disallowedStatTypes)
        defaultStatCollector?.storage.remove(disallowedStatTypes: disallowedStatTypes)
        notificationStatCollector?.storage.remove(disallowedStatTypes: disallowedStatTypes)
    }
    
    private func isAllowed(_ statType: StatType) -> Bool {
        return allowedStatTypes.contains(statType)
    }
    
    private func removeAll() {
        self.dailyStatCollector?.removeAll()
        self.defaultStatCollector?.removeAll()
        self.notificationStatCollector?.removeAll()
    }
    
    @_spi(SendbirdInternal) public func getDeviceId() -> String {
        guard let deviceId = Self.baseStorage.string(forKey: Constant.uniqueDeviceId) else {
            let newDeviceId = UUID().uuidString
            Self.baseStorage.setValue(newDeviceId, forKey: Constant.uniqueDeviceId)
            Logger.stat.debug("Created new unique device ID for stat: \(newDeviceId)")
            return newDeviceId
        }
        Logger.stat.debug("Loaded unique device ID for stat: \(deviceId)")
        return deviceId
    }
    
    // MARK: Injectable
    @_spi(SendbirdInternal) public func resolve(with dependency: (any Dependency)?) {
        self.dependency = dependency
    }
    
    #if DEBUG
    // For tests
    @_spi(SendbirdInternal) public weak var delegate: StatManagerInternalDelegate?
    @_spi(SendbirdInternal) public var mockStatUploadResult: Bool?
    @_spi(SendbirdInternal) public var mockError: AuthError?
    #endif
}

// MARK: - EventDelegate

extension StatManager: EventDelegate {
    @_spi(SendbirdInternal) public func didReceiveSBCommandEvent(command: SBCommand) async {
        switch command {
        case let command as LoginEvent:
            // Do this only if login was successful
            guard (command.hasError ?? false) == false else { return }
            
            update(allowedStatTypes: allowedStatTypes(of: command))
            
            Logger.stat.debug("Building stat collectors.")
            
            if let defaultConfig = command.appInfo?.defaultConfig {
                Logger.stat.debug("Default stat config from server: \(defaultConfig.debugDescription)")
                self.defaultStatCollector?.statConfig = defaultConfig
            }
            
#if DEBUG
            if let statConfig = self.defaultConfigForTest {
                self.defaultStatCollector?.statConfig = statConfig
            }
#endif
            
            if let notificationConfig = command.appInfo?.notificationConfig {
                Logger.stat.debug("Notification stat config: \(notificationConfig.debugDescription)")
                self.notificationStatCollector?.statConfig = notificationConfig
                self.notificationStatCollector?.enabled = true
            } else {
                Logger.stat.debug("Notification stat doesn't exist in LOGI.")
                self.notificationStatCollector?.enabled = false
            }
            
            if command.isStatsCollectAllowed {
                if command.isStatsUploadAllowed {
                    enable()
                } else {
                    changeToCollectOnly()
                }
            } else {
                disable()
            }
        case let command as BusyEvent:
            self.hasReceivedBUSYatLeastOnce = true 
        default: break
        }
    }
    
    @_spi(SendbirdInternal) public func didReceiveInternalEvent(command: InternalEvent) {
        switch command {
        case is ConnectionStateEvent.Logout:
            disable()
        case _ as WebSocketStatEvent.WebSocketStartEvent:
            self.restoreWebSocketOpenedEvent()
            self.connectionStartedAt = Date().milliSeconds
        case let command as WebSocketStatEvent.WebSocketOpenedEvent:
            self.wsOpenedEvent = command
            
        case let command as WebSocketStatEvent.WebSocketFailedEvent:
            self.append(failedEvent: command)
        case let command as WebSocketStatEvent.WebSocketLoginTimeoutEvent:
            // login timeout case
            self.append(timeoutEvent: command)
        case let command as WebSocketStatEvent.WebSocketDisconnectEvent:
            self.append(disconnectEvent: command)
            
        case _ as SessionExpirationEvent.Refreshed:
            self.append(
                disconnectEvent: WebSocketStatEvent.WebSocketDisconnectEvent(
                    error: AuthClientError.sessionKeyExpired.asAuthError,
                    reason: .sessionExpired
                )
            )
        default: break
        }
    }
    
    @_spi(SendbirdInternal) public func allowedStatTypes(of loginEvent: LoginEvent) -> Set<StatType> {
        guard let applicationAttributes = loginEvent.appInfo?.typedApplicationAttributes else {
            return []
        }
        
        return allowedStatTypes(of: applicationAttributes)
    }
    
    @_spi(SendbirdInternal) public func allowedStatTypes(of applicationAttributes: Set<AuthAppInfo.ApplicationAttribute>) -> Set<StatType> {
        StatType.allCases.reduce(into: Set<StatType>()) { allowedTypes, statType in
            if applicationAttributes.contains(statType.applicationAttributeAllowUse) {
                allowedTypes.insert(statType)
            }
        }
    }
}

extension StatManager {
    @_spi(SendbirdInternal) public static var baseStorage: UserDefaults { UserDefaults(suiteName: Constant.suiteName) ?? .standard }
    
    @_spi(SendbirdInternal) public struct Constant {
        static let suiteName = "com.sendbird.sdk.stat.storage"
        static let uniqueDeviceId = "com.sendbird.sdk.stat.unique_device_id"
    }
}

extension StatManager: StatManagerDelegate {
    @_spi(SendbirdInternal) public func statManager(_ statCollector: any StatCollectorContract, didFailSendStats: AuthError) {
        self.retryCount -= 1
        if self.retryCount <= 0 {
            self.retryCount = Self.maxRetryCount
            self.changeToCollectOnly()
        }
    }
    
    @_spi(SendbirdInternal) public func statManager(_ statCollector: any StatCollectorContract, newState: State) {
        self.changeToCollectOnly()
    }
    
    @_spi(SendbirdInternal) public func isStatManagerUploadable() -> Bool {
        self.state.isUploadable
    }
    
    @_spi(SendbirdInternal) public func statManager(_ statCollector: any StatCollectorContract, didSentStats: [any BaseStatType]) {
#if DEBUG
        self.delegate?.statManager(self, didSendStatsThrough: statCollector)
#endif
    }
}

#if DEBUG
// For tests
extension StatManager {
    @_spi(SendbirdInternal) public func waitUntilAllOperationsAreFinished() {
        queue.waitUntilAllOperationsAreFinished()
    }
    
    @_spi(SendbirdInternal) public func setMockResult(enabled: Bool, error: AuthError?) {
        self.apiClient.setMockResult(enabled: enabled, error: error)
    }
}
#endif
