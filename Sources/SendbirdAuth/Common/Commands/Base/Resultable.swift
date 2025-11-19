//
//  Resultable.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/22.
//

import Foundation

package typealias ResultableRequest = Resultable & Requestable
package typealias ResultableWSRequest = Resultable & WSRequestable

package protocol AnyResultable {
    func handleCommand(_ command: SBCommand?, handler: Any?)
    func handleError(_ error: AuthError?, handler: Any?)
}

package protocol Resultable: AnyResultable {
    associatedtype ResultType: Decodable
    
    typealias CommandHandler = (_ command: Self.ResultType?, _ error: AuthError?) -> Void
    
    var resultType: ResultType.Type { get }
    
    func decodeResult(from data: Data, decoder: JSONDecoder) -> Result<ResultType, AuthError>
}

extension Resultable {
    package func decodeResult(from data: Data, decoder: JSONDecoder) -> Result<ResultType, AuthError> {
        return decodeGenericResult(data: data, decoder: decoder)
    }
    
    package func decodeGenericResult<T: Decodable>(data: Data, decoder: JSONDecoder) -> Result<T, AuthError> {
        do {
            if let type = T.self as? RawDataRespondable.Type,
               let result = try type.init(from: data) as? T {
                return .success(result)
            } else {
                let result = try decoder.decode(T.self, from: data)
                return .success(result)
            }
        } catch {
            if let error = error as? DecodingError {
                Logger.client.verbose("Failed to decode result: \(String(describing: type(of: T.self))) with error: \(error)")
            }
            
            return .failure(.error(from: data))
        }
    }
    
    package func handleCommand(_ command: SBCommand?, handler: Any?) {
        guard let handler = handler as? Self.CommandHandler else {
            return
        }
        
        guard let result = command as? ResultType else {
            handler(nil, AuthCoreError.malformedData.asAuthError)
            return
        }

        handler(result, nil)
    }
    
    package func handleError(_ error: AuthError?, handler: Any?) {
        guard let handler = handler as? Self.CommandHandler else { return }
        handler(nil, error ?? AuthCoreError.malformedData.asAuthError)
    }
}
