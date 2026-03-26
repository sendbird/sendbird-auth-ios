//
//  SessionState.swift
//  SendbirdAuth
//
//  Created by OpenAI Codex on 2026/03/26.
//

import Foundation

@_spi(SendbirdInternal) public enum SessionState {
    case connected
    case refreshing
    case none
}
