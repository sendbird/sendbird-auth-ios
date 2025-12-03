//
//  AuthUserConnectionStatus.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/13/25.
//

/// User connection statuses for `User`.
@_spi(SendbirdInternal) public enum AuthUserConnectionStatus: Int, Codable {
    /// For unavailable user.
    case nonAvailable = 0
    
    /// For on-line user.
    case online = 1
    
    /// For off-line user.
    case offline = 2
}

extension AuthUserConnectionStatus {
    @_spi(SendbirdInternal) public typealias RawValue = Bool?
    
    @_spi(SendbirdInternal) public init(rawValue: Bool?) {
        if let rawValue = rawValue {
            self = rawValue ? .online : .offline
        } else {
            self = .nonAvailable
        }
    }
    
    @_spi(SendbirdInternal) public var rawValue: Bool? {
        switch self {
        case .offline: return false
        case .online: return true
        case .nonAvailable: return nil
        }
    }
    
    /// Default constructor.
    ///
    /// - Parameter decoder: `Decoder` instance
    @_spi(SendbirdInternal) public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let boolValue = try container.decode(Bool.self)
        self.init(rawValue: boolValue)
    }
    
    /// Encodes this object.
    ///
    /// - Parameter encoder: `Encoder` instance
    @_spi(SendbirdInternal) public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
