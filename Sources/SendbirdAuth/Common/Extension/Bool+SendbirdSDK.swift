//
//  Bool+SendbirdSDK.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/12/02.
//

import Foundation

extension Bool {
    @_spi(SendbirdInternal) public var asInt: Int {
        self ? 1 : 0
    }
}
