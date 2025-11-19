//
//  StatRequestBalancer.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/06/03.
//

import Foundation

protocol StatRequestBalancer {
    static func distributeRequest(delayRange: Int) async throws
}
