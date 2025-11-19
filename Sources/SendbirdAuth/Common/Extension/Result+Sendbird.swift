//
//  Result+Sendbird.swift
//  
//
//  Created by Minhyuk Kim on 2022/06/05.
//

import Foundation

package extension Result {
    var failure: Failure? {
        switch self {
        case .failure(let error): return error
        case .success: return nil
        }
    }
    
    var success: Success? {
        switch self {
        case .failure: return nil
        case .success(let success): return success
        }
    }
    
    var isFailure: Bool { failure != nil }
    var isSuccess: Bool { success != nil }

    init?(_ success: Success?, _ failure: Failure?) {
        if let error = failure {
            self = .failure(error)
        } else if let value = success {
            self = .success(value)
        } else {
            return nil
        }
    }
}
