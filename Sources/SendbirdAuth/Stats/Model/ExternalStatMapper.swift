//
//  ExternalStatMapper.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2023/04/07.
//

import Foundation

/// Handler type for creating stats from external data
/// - Parameters:
///   - statType: The stat type
///   - data: The stat data as AnyCodable dictionary
///   - timestamp: The timestamp in milliseconds
///   - statId: Optional stat ID
///   - includeRuntimeId: Whether to include runtime ID
/// - Returns: A stat instance conforming to BaseStatType, or nil if creation fails
@_spi(SendbirdInternal) public typealias ExternalStatHandler = (
    _ statType: StatType,
    _ data: [String: AnyCodable]?,
    _ timestamp: Int64,
    _ statId: String?,
    _ includeRuntimeId: Bool
) -> (any BaseStatType)?

@_spi(SendbirdInternal) public struct ExternalStatMapper {

    // MARK: - Registered Handlers

    private static var handlers: [StatType: ExternalStatHandler] = [:]
    private static let lock = NSLock()

    /// Registers a custom handler for a specific stat type.
    /// - Parameters:
    ///   - statType: The stat type to register the handler for
    ///   - handler: The handler that creates the appropriate stat instance
    @_spi(SendbirdInternal) public static func register(
        statType: StatType,
        handler: @escaping ExternalStatHandler
    ) {
        lock.lock()
        defer { lock.unlock() }
        handlers[statType] = handler
    }

    /// Unregisters the handler for a specific stat type.
    /// - Parameter statType: The stat type to unregister
    @_spi(SendbirdInternal) public static func unregister(statType: StatType) {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeValue(forKey: statType)
    }

    /// Clears all registered handlers.
    @_spi(SendbirdInternal) public static func clearAllHandlers() {
        lock.lock()
        defer { lock.unlock() }
        handlers.removeAll()
    }

    // MARK: - Mapping

    @_spi(SendbirdInternal) public static func map(type: String, data: [String: Any], timestamp: Int64) -> BaseStat? {
        return map(type: type, data: data, timestamp: timestamp, statId: nil, includeRuntimeId: false) as? BaseStat
    }

    @_spi(SendbirdInternal) public static func map(
        type: String,
        data: [String: Any],
        timestamp: Int64,
        statId: String?,
        includeRuntimeId: Bool
    ) -> (any BaseStatType)? {
        guard let statType = StatType(rawValue: type) else {
            Logger.external.error("Invalid stat type", type)
            return nil
        }

        guard statType.isExternal else {
            Logger.external.error("This stat type is not external stat", type)
            return nil
        }

        let anyCodableData = data.anyCodable

        // Check for registered handler first
        lock.lock()
        let handler = handlers[statType]
        lock.unlock()

        // INFO: AIAgent 는 aiagent initializer 에서 handler 등록
        if let handler = handler {
            return handler(statType, anyCodableData, timestamp, statId, includeRuntimeId)
        }

        // Built-in handling for known external stat types
        switch statType {
        case .notificationStats:
            // INFO: UIKit 에서 noti stat 들어오는거 처리안되고 있어서 추가 (20260128)
            return decodeStat(NotificationStat.self, type: type, data: data, timestamp: timestamp)

        default:
            // No handler registered for this external stat type
            Logger.external.error("No handler registered for external stat type", type)
            return nil
        }
    }

    // MARK: - Generic Stat Decoding

    /// Decodes a stat using the standard stat JSON structure
    /// - Parameters:
    ///   - statClass: The stat type to decode
    ///   - type: The stat type string
    ///   - data: The data dictionary (will be placed under "data" key)
    ///   - timestamp: The timestamp in milliseconds
    /// - Returns: Decoded stat instance or nil if decoding fails
    private static func decodeStat<T: BaseStatType>(
        _ statClass: T.Type,
        type: String,
        data: [String: Any],
        timestamp: Int64
    ) -> T? {
        // Construct the wrapper structure that stats expect
        let wrapper: [String: Any] = [
            "ts": timestamp,
            "stat_type": type,
            "data": data
        ]
        return T._make(from: wrapper, decoder: SendbirdAuth.authDecoder)
    }
}
