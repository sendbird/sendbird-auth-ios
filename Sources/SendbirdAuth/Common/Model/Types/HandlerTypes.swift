//
//  Handlers.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

/// User handler
@_spi(SendbirdInternal) public typealias AuthUserHandler = ((_ user: AuthUser?, _ error: AuthError?) -> Void)

/// Void handler
@_spi(SendbirdInternal) public typealias VoidHandler = (() -> Void)

/// Error handler
@_spi(SendbirdInternal) public typealias AuthErrorHandler = ((_ error: AuthError?) -> Void)

/// Binary progress handler
@_spi(SendbirdInternal) public typealias ProgressHandler = ((_ bytesSent: Int64,
                                        _ totalBytesSent: Int64,
                                        _ totalBytesExpectedToSend: Int64) -> Void)

/// multi file progress handler
@_spi(SendbirdInternal) public typealias MultiProgressHandler = ((_ requestId: String?,
                                          _ bytesSent: Int64,
                                        _ totalBytesSent: Int64,
                                        _ totalBytesExpectedToSend: Int64) -> Void)

@_spi(SendbirdInternal) public typealias DataResponseHandler = ((Data?, AuthError?) -> Void)

@_spi(SendbirdInternal) public typealias ResponseHandler = (([String: Any]?, AuthError?) -> Void)

@_spi(SendbirdInternal) public typealias AnyResponseHandler = ((Any?, AuthError?) -> Void)

/// bool handler
@_spi(SendbirdInternal) public typealias BoolHandler = ((Bool, AuthError?) -> Void)

/// timer handler
@_spi(SendbirdInternal) public typealias TimerHandler = (SBTimer) -> Void

/// internal error handler
@_spi(SendbirdInternal) public typealias ErrorHandler = (Error?) -> Void
