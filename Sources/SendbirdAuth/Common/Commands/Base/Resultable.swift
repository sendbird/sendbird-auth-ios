//
//  Resultable.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/22.
//

import Foundation

@_spi(SendbirdInternal) public typealias ResultableRequest = Resultable & Requestable
@_spi(SendbirdInternal) public typealias ResultableWSRequest = Resultable & WSRequestable

@_spi(SendbirdInternal) public protocol AnyResultable {
    func handleCommand(_ command: SBCommand?, handler: Any?)
    func handleError(_ error: AuthError?, handler: Any?)
}

@_spi(SendbirdInternal) public protocol Resultable: AnyResultable {
    associatedtype ResultType: Decodable
    
    typealias CommandHandler = (_ command: Self.ResultType?, _ error: AuthError?) -> Void
    
    var resultType: ResultType.Type { get }
    
    func decodeResult(from data: Data, decoder: JSONDecoder) -> Result<ResultType, AuthError>
}

extension Resultable {
    @_spi(SendbirdInternal) public func decodeResult(from data: Data, decoder: JSONDecoder) -> Result<ResultType, AuthError> {
        return decodeGenericResult(data: data, decoder: decoder)
    }
    
    @_spi(SendbirdInternal) public func decodeGenericResult<T: Decodable>(data: Data, decoder: JSONDecoder) -> Result<T, AuthError> {
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
    
    @_spi(SendbirdInternal) public func handleCommand(_ command: SBCommand?, handler: Any?) {
        guard let handler = handler as? Self.CommandHandler else {
            return
        }
        
        guard let result = command as? ResultType else {
            handler(nil, AuthCoreError.malformedData.asAuthError)
            return
        }

        handler(result, nil)
    }
    
    @_spi(SendbirdInternal) public func handleError(_ error: AuthError?, handler: Any?) {
        guard let handler = handler as? Self.CommandHandler else { return }
        handler(nil, error ?? AuthCoreError.malformedData.asAuthError)
    }
}
