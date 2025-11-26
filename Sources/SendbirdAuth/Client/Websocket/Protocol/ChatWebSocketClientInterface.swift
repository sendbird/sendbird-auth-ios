//
//  ChatWebSocketClientInterface.swift
//  SendbirdChat
//
//  Created by Kai Lee on 9/10/25.
//

import Foundation

@_spi(SendbirdInternal) public protocol ChatWebSocketClientInterface: Actor, EventStreamable<WebSocketClientEvent> {
    var routerConfig: CommandRouterConfiguration { get async }
    var sendbirdConfig: SendbirdConfiguration { get async }
    var state: AuthWebSocketConnectionState { get async }
    var currentRequest: URLRequest? { get async }
    
    init(
        routerConfig: CommandRouterConfiguration,
        sendbirdConfig: SendbirdConfiguration,
        webSocketEngine: (any ChatWebSocketEngine)?
    )
    func disconnect() async
    func forceDisconnect() async
    func connect(
        with urlString: String,
        accessToken: String?,
        sessionKey: String?
    ) async
    func send<R: WSRequestable>(request: R) async throws
    func setPing(interval: TimeInterval) async
    func setWatchdog(interval: TimeInterval) async
    func startPingTimer() async
    func createNewClient() async -> any ChatWebSocketClientInterface
    
    func setRouterConfig(to config: CommandRouterConfiguration) async
}
