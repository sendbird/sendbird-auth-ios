//
//  Handlers.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

/// User handler
package typealias AuthUserHandler = ((_ user: AuthUser?, _ error: AuthError?) -> Void)

/// Void handler
package typealias VoidHandler = (() -> Void)

/// Error handler
package typealias AuthErrorHandler = ((_ error: AuthError?) -> Void)

/// Binary progress handler
package typealias ProgressHandler = ((_ bytesSent: Int64,
                                        _ totalBytesSent: Int64,
                                        _ totalBytesExpectedToSend: Int64) -> Void)

/// multi file progress handler
package typealias MultiProgressHandler = ((_ requestId: String?,
                                          _ bytesSent: Int64,
                                        _ totalBytesSent: Int64,
                                        _ totalBytesExpectedToSend: Int64) -> Void)

package typealias DataResponseHandler = ((Data?, AuthError?) -> Void)

package typealias ResponseHandler = (([String: Any]?, AuthError?) -> Void)

package typealias AnyResponseHandler = ((Any?, AuthError?) -> Void)

/// bool handler
package typealias BoolHandler = ((Bool, AuthError?) -> Void)

/// timer handler
package typealias TimerHandler = (SBTimer) -> Void

/// internal error handler
package typealias ErrorHandler = (Error?) -> Void
