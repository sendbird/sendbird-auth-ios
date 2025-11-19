//
//  SessionValidator.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

import Foundation

package protocol SessionValidator: AnyObject {
    func validateSession(isSessionRequired: Bool) throws -> String?
    func validateResponse<R>(_ response: R?, error: AuthError?) -> Bool
    var state: SessionManager.SessionState { get }
}
