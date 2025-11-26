//
//  InternalSessionDelegate.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

@_spi(SendbirdInternal) public protocol InternalSessionDelegate: AnyObject {
    func didSessionTokenFailToRefresh(error: AuthClientError)
    func didSessionKeyFailToRefresh(error: AuthClientError)
    func didSessionKeyRefresh(key: Session, requireReconnect: Bool)
    func didSessionTokenRevoke()

    func refreshSessionKey(authToken: String?, expiringSession: Bool, expiresIn: Int64?, completionHandler: ((Bool, Session?, AuthError?) -> Void)?)
}
