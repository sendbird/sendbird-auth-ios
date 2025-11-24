//
//  ErrorMessage.swift
//  SendbirdChat
//
//  Created by Kai Lee on 7/3/25.
//

public enum ErrorMessage: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notAuthorized: return "Not authorized to call"
        case .requestNotSupport: return "Not supported request type"
        case .endpointNotExist: return "Endpoint not exist"
        case .badParameters: return "Bad parameters"
        case .messageDoesntBelongToChannel: return "The message doesn't belong to thie channel."
        case .notResendable: return "The message can only resend if the problem is due to network related error."
        case .emptyParameter(let param): return "\(param) should not be empty"
        case .invalid(let param): return "Invalid \(param)."
        case .copyOnlySucceededMessage: return "Only succeeded message can be copied."
        case .copyOnlyWithoutPollMessage: return "Only messages without polls can be copied."
        case .dependentObjectIsNil: return "🚨Please make sure you call the function after calling `SendbirdChat.initialize` once. This can also happen if `SendbirdChat.initialize` is called multiple times with different `applicationId` or `isLocalCachingEnabled`.🚨"
        case .alreadyLoggedInDifferentUser: return "Already logged in as a different user. Call disconnect() first."
        case .notResolved: return "The object is not resolved. Please call resolved(with:) before calling this method."
        }
    }
    
    case notAuthorized
    case requestNotSupport
    case endpointNotExist
    case badParameters
    case messageDoesntBelongToChannel
    case notResendable
    case emptyParameter(_ param: String)
    case invalid(_ param: String)
    case copyOnlySucceededMessage
    case copyOnlyWithoutPollMessage
    case dependentObjectIsNil
    case alreadyLoggedInDifferentUser
    case notResolved
}
