//
//  Dependency.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/13/25.
//

import Foundation

@_spi(SendbirdInternal) public protocol Dependency: AnyObject {
    var service: QueueService { get }
    var config: SendbirdConfiguration { get }
    var stateData: ConnectionStateData { get }

    var requestQueue: RequestQueue { get }
    var deviceConnectionManager: DeviceConnectionManager { get }
    var statManager: StatManager { get }

    var commonSharedData: CommonSharedData { get }

    var decoder: JSONDecoder { get }
}
