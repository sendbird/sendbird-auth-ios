//
//  DecoderInfoKey.swift
//  SendbirdChat
//
//  Created by Jed Gyeong on 5/12/25.
//

import Foundation

@_spi(SendbirdInternal) public struct DecoderInfoKey {
    @_spi(SendbirdInternal) public static let dependency = CodingUserInfoKey(rawValue: "sendbird_auth_dependency")!
}
