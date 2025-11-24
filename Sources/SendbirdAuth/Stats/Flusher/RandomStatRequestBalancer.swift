//
//  RandomStatRequestBalancer.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2022/06/03.
//

import Foundation

public class RandomStatRequestBalancer: StatRequestBalancer {

    public static func distributeRequest(delayRange: Int = 0) async throws {
        let delay = TimeInterval.random(in: (0...Double(delayRange)))
        Logger.stat.debug("\(delay) seconds delay for stats")
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}
