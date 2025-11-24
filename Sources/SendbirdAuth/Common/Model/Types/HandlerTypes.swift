//
//  Handlers.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

/// User handler
public typealias AuthUserHandler = ((_ user: AuthUser?, _ error: AuthError?) -> Void)

/// Void handler
public typealias VoidHandler = (() -> Void)

/// Error handler
public typealias AuthErrorHandler = ((_ error: AuthError?) -> Void)

/// Binary progress handler
public typealias ProgressHandler = ((_ bytesSent: Int64,
                                        _ totalBytesSent: Int64,
                                        _ totalBytesExpectedToSend: Int64) -> Void)

/// multi file progress handler
public typealias MultiProgressHandler = ((_ requestId: String?,
                                          _ bytesSent: Int64,
                                        _ totalBytesSent: Int64,
                                        _ totalBytesExpectedToSend: Int64) -> Void)

public typealias DataResponseHandler = ((Data?, AuthError?) -> Void)

public typealias ResponseHandler = (([String: Any]?, AuthError?) -> Void)

public typealias AnyResponseHandler = ((Any?, AuthError?) -> Void)

/// bool handler
public typealias BoolHandler = ((Bool, AuthError?) -> Void)

/// timer handler
public typealias TimerHandler = (SBTimer) -> Void

/// internal error handler
public typealias ErrorHandler = (Error?) -> Void
