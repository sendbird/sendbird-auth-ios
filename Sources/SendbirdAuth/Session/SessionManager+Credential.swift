//
//  SessionManager+Credential.swift
//  SendbirdAuth
//
//  Created by Kai Lee on 2026/02/06.
//

import Foundation

@_spi(SendbirdInternal)
extension SessionManager {
    /// SessionManager의 credential 상태를 나타냅니다.
    /// - initialized: applicationId/userId가 아직 설정되지 않은 상태 (placeholder)
    /// - active: 유효한 applicationId/userId가 설정된 상태
    @_spi(SendbirdInternal) public enum Credential: Equatable {
        case initialized
        case active(applicationId: String, userId: String)

        var applicationId: String {
            switch self {
            case .initialized:
                return ""
            case .active(let applicationId, _):
                return applicationId
            }
        }

        var userId: String {
            switch self {
            case .initialized:
                return ""
            case .active(_, let userId):
                return userId
            }
        }

        var isActive: Bool {
            if case .active = self { return true }
            return false
        }
    }
}
