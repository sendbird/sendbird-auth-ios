//
//  RequestQueue.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2022/01/14.
//

import Foundation

@_spi(SendbirdInternal) public protocol RequestQueueSendable: AnyObject {
    var requestTimeout: TimeInterval { get }
    
    func send<R: APIRequestable>(
        request: R,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]?,
        progressHandler: MultiProgressHandler?,
        completion: R.CommandHandler?
    )
    func sendImmediately<R: APIRequestable>(
        request: R,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]?,
        progressHandler: MultiProgressHandler?,
        completion: R.CommandHandler?
    )
    func send<R: ResultableWSRequest>(request: R, completion: R.CommandHandler?)
    func send<R: WSRequestable>(request: R)
}

@_spi(SendbirdInternal) public class RequestQueue: RequestQueueSendable, Injectable {
    // MARK: Injectable
    @_spi(SendbirdInternal) public func resolve(with dependency: (any Dependency)?) {
        self.dependency = dependency
    }
    
    @_spi(SendbirdInternal) public struct CodingInfoKey {
        @_spi(SendbirdInternal) public static let isApi = CodingUserInfoKey(rawValue: "isApi")!
    }
    
    @_spi(SendbirdInternal) public weak var sessionValidator: SessionValidator?
     
    @_spi(SendbirdInternal) public var webSocketConnectionState: AuthWebSocketConnectionState { router.webSocketConnectionState }
    
    @_spi(SendbirdInternal) public var requestTimeout: TimeInterval {
        config?.requestTimeout ?? SendbirdConfiguration.requestTimeoutDefault
    }
    
    @InternalAtomic @_spi(SendbirdInternal) public private(set) var router: CommandRouter
    @InternalAtomic @_spi(SendbirdInternal) public private(set) var connectionState: ConnectionStateEventable = ConnectionStateEvent.Logout(userId: "", error: nil)
    
    private let service: DispatchQueue
    
    // MARK: Injectable
    @DependencyWrapper private var dependency: Dependency?
    @_spi(SendbirdInternal) public var stateData: ConnectionStateData? { dependency?.stateData }
    @_spi(SendbirdInternal) public var deviceConnectionManager: DeviceConnectionManager? { dependency?.deviceConnectionManager }
    private var config: SendbirdConfiguration? { dependency?.config }

    @_spi(SendbirdInternal) public typealias QueuedRequestHandler = (() -> ProcessResult)
    private var queuedRequests: [QueuedRequestHandler] = []
    
    private var hasSessionDelegate: Bool { deviceConnectionManager?.hasSessionDelegate ?? false }
    
    @_spi(SendbirdInternal) public init(
        commandRouter: CommandRouter,
        sessionValidator: SessionValidator
    ) {
        self.router = commandRouter
        self.sessionValidator = sessionValidator
        self.service = DispatchQueue(label: "com.sendbird.chat.request_queue_\(UUID().uuidString)")
    }
    
    @_spi(SendbirdInternal) public func updateConfig(_ config: CommandRouterConfiguration) {
        router.setRouterConfig(config)
    }
    
    @_spi(SendbirdInternal) public func isConnected() -> Bool {
        let connectionState = self.router.webSocketManager.state
        return connectionState is ConnectedState
    }

    // MARK: - Send methods

    @_spi(SendbirdInternal) public func send<R: APIRequestable>(
        request: R,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]? = nil,
        progressHandler: MultiProgressHandler? = nil,
        completion: R.CommandHandler?
    ) {
        let timeout = requestTimeout
        
        service.async { [weak self] in
            guard let self = self else { return }

            // Use a shared completion state across timer and queue processing
            let completionGuard = CompletionGuard()
            
            let timer = SBTimer(
                timeInterval: timeout,
                userInfo: nil,
                onBoard: nil
            ) {
                completionGuard.finishOnce {
                    completion?(nil, AuthClientError.connectionRequired.asAuthError)
                }
            }
            
            let queueItem: QueuedRequestHandler = {
                // timer was expired, don't process
                guard timer.valid else {
                    return .process
                }
                
                let processResult = self.apiProcessStrategy(request: request)
                switch processResult {
                case .onHold:
                    return processResult
                case .error(let error):
                    timer.abort()
                    completionGuard.finishOnce {
                        completion?(nil, error)
                    }
                    return processResult
                case .process:
                    break
                }

                timer.abort()
                
                do {
                    let sessionKey = try self.sessionValidator?.validateSession(isSessionRequired: request.isSessionRequired)
                    
                    self.router.send(
                        request: request,
                        sessionKey: sessionKey,
                        wsEventDeduplicationRules: wsEventDeduplicationRules,
                        progressHandler: progressHandler
                    ) { response, error in
                        guard let sessionValidator = self.sessionValidator else {
                            completionGuard.finishOnce {
                                completion?(nil, error ?? AuthClientError.unknownError.asAuthError)
                            }
                            return
                        }
                        
                        let shouldContinue = sessionValidator.validateResponse(response, error: error)
                        
                        if shouldContinue == false, request.isSessionRequired {
                            self.send(request: request, progressHandler: progressHandler, completion: completion)
                            return
                        }
                        
                        completionGuard.finishOnce {
                            completion?(response, error)
                        }
                    }
                    return .process
                } catch let err {
                    completionGuard.finishOnce {
                        completion?(nil, err.asAuthError())
                    }
                    return .process
                }
            }
            
            self.queuedRequests.append(queueItem)
            self.processQueuedRequests()
        }
    }
    
    @_spi(SendbirdInternal) public func send<R: APIRequestable>(
        request: R,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]? = nil,
        progressHandler: MultiProgressHandler? = nil
    ) async throws -> R.ResultType {
        return try await withThrowingTaskGroup(of: R.ResultType.self) { group in
            group.addTask {
                return try await withCheckedThrowingContinuation({ continuation in
                    self.send(
                        request: request,
                        wsEventDeduplicationRules: wsEventDeduplicationRules,
                        progressHandler: progressHandler
                    ) { res, err in
                        if let res {
                            continuation.resume(returning: res)
                        } else {
                            continuation.resume(throwing: err ?? AuthClientError.unknownError.asAuthError(message: "Error occurred while sending request(\(request))"))
                        }
                    }
                })
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(20 * 1_000_000_000))
                throw AuthClientError.timerWasExpired.asAuthError(message: "Timed out after \(20) seconds while sending request(\(request))")
            }

            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw AuthClientError.unknownError.asAuthError(message: "Unexpected error occurred while sending request(\(request))")
            }
            return result
        }
    }
        
    /// This method should be used when theres a case to send api request immediately
    /// without queueing (i.e. recursively attempt to send request after one prior request fails)
    /// due to avoiding deadlock on queue
    @_spi(SendbirdInternal) public func sendImmediately<R: APIRequestable>(
        request: R,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]? = nil,
        progressHandler: MultiProgressHandler? = nil,
        completion: R.CommandHandler?
    ) {
        if connectionState is ConnectionStateEvent.Logout {
            completion?(nil, AuthClientError.connectionRequired.asAuthError)
            return
        }
        
        do {
            let sessionKey = try self.sessionValidator?.validateSession(isSessionRequired: request.isSessionRequired)
            
            router.send(
                request: request,
                sessionKey: sessionKey,
                wsEventDeduplicationRules: wsEventDeduplicationRules,
                progressHandler: progressHandler
            ) { [weak self] response, error in
                guard let self = self else { return }
                guard let sessionValidator = self.sessionValidator else {
                    completion?(nil, error ?? AuthClientError.unknownError.asAuthError)
                    return
                }
                
                let shouldContinue = sessionValidator.validateResponse(response, error: error)
                
                if shouldContinue == false, request.isSessionRequired {
                    self.send(
                        request: request,
                        wsEventDeduplicationRules: wsEventDeduplicationRules,
                        progressHandler: progressHandler,
                        completion: completion
                    )
                    return
                }
                
                completion?(response, error)
            }
        } catch let err {
            completion?(nil, err as? AuthError)
        }
    }

    // MARK: - RequestParameter based methods

    /**
     GET API Request

     - Parameters:
        - path: The server endpoint to which the request is made. Accepts any type conforming to `URLPathConvertible`
        - queryParams: URL query parameters to append to the endpoint.
        - additionalBody: Additional encodable objects to be included in the request body. `encode(to:)` function will invoked, and will be included in the query parameters.
        - header: HTTP headers to include in the request.
        - isSessionRequired: Indicates if the request needs session-based authentication. Default is true.
        - isLoginRequired: Indicates if the user must be logged in to perform the request. Default is true.
        - progressHandler: A closure to monitor the progress of the request. Useful for tracking upload/download progress.
        - completionHandler: A closure called upon request completion, returning either a decoded response model or an error.

     - Note:
        - `R` must conform to `Decodable` to be used for the expected response model - This means you **have** to implement a completion handler.
        - If the response of the request is unused, declare the result as type of `EmptyResponse` or `DefaultResponse`
     */
    @_spi(SendbirdInternal) public func get<R: Decodable>(
        path: some URLPathConvertible,
        queryParams: RequestParameter = .init(),
        additionalBody: Encodable...,
        header: [String: String] = [:],
        isSessionRequired: Bool = true,
        isLoginRequired: Bool = true,
        progressHandler: MultiProgressHandler? = nil,
        completionHandler: ((Result<R, AuthError>) -> Void)?
    ) {
        let request = APIRequest<R>(
            method: .get,
            url: path,
            version: "/v3",
            body: queryParams,
            additionalBodies: additionalBody,
            headers: header,
            multipart: [:],
            queryParameters: queryParams,
            isSessionRequired: isSessionRequired,
            isLoginRequired: isLoginRequired
        )

        self.send(request: request, progressHandler: progressHandler) { response, error in
            completionHandler?(.init(response, error))
        }
    }

    /**
     POST API Request

     - Parameters:
        - path: The server endpoint to which the request is made. Accepts any type conforming to `URLPathConvertible`
        - body: The primary content of the request. This is eventually encoded as a dictionary with the specified key value pairs.
        - additionalBody: Additional encodable objects to be included in the request body. `encode(to:)` function will invoked, and will be included in the body payload as a top-level JSON dictionary.
        - multipart: Data for multipart/form-data requests, typically files or binary data, keyed by form field name.
        - header: HTTP headers to include in the request.
        - queryParams: URL query parameters to append to the endpoint.
        - isSessionRequired: Indicates if the request needs session-based authentication. Default is true.
        - isLoginRequired: Indicates if the user must be logged in to perform the request. Default is true.
        - sendImmediately: If true, sends the request immediately without queueing.
        - wsEventDeduplicationRules: WS events that should be ignored upon receival.
        - progressHandler: A closure to monitor the progress of the request. Useful for tracking upload/download progress.
        - completionHandler: A closure called upon request completion, returning either a decoded response model or an error.

     - Note:
        - `R` must conform to `Decodable` to be used for the expected response model - This means you **have** to implement a completion handler.
        - If the response of the request is unused, declare the result as type of `EmptyResponse` or `DefaultResponse`
     */
    @_spi(SendbirdInternal) public func post<R: Decodable>(
        path: some URLPathConvertible,
        body: RequestParameter = .init(),
        additionalBody: Encodable...,
        multipart: [String: Any] = [:],
        header: [String: String] = [:],
        queryParams: RequestParameter = .init(),
        isSessionRequired: Bool = true,
        isLoginRequired: Bool = true,
        sendImmediately: Bool = false,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]? = nil,
        progressHandler: MultiProgressHandler? = nil,
        completionHandler: ((Result<R, AuthError>) -> Void)?
    ) {
        let request = APIRequest<R>(
            method: .post,
            url: path,
            version: "/v3",
            body: body,
            additionalBodies: additionalBody,
            headers: header,
            multipart: multipart,
            queryParameters: queryParams,
            isSessionRequired: isSessionRequired,
            isLoginRequired: isLoginRequired
        )

        if sendImmediately {
            self.sendImmediately(
                request: request,
                wsEventDeduplicationRules: wsEventDeduplicationRules,
                progressHandler: progressHandler
            ) { response, error in
                completionHandler?(.init(response, error))
            }
        } else {
            self.send(
                request: request,
                wsEventDeduplicationRules: wsEventDeduplicationRules,
                progressHandler: progressHandler
            ) { response, error in
                completionHandler?(.init(response, error))
            }
        }
    }

    /**
     PUT API Request

     - Parameters:
        - path: The server endpoint to which the request is made. Accepts any type conforming to `URLPathConvertible`
        - body: The primary content of the request. This is eventually encoded as a dictionary with the specified key value pairs.
        - additionalBody: Additional encodable objects to be included in the request body. `encode(to:)` function will invoked, and will be included in the body payload as a top-level JSON dictionary.
        - multipart: Data for multipart/form-data requests, typically files or binary data, keyed by form field name.
        - header: HTTP headers to include in the request.
        - queryParams: URL query parameters to append to the endpoint.
        - isSessionRequired: Indicates if the request needs session-based authentication. Default is true.
        - isLoginRequired: Indicates if the user must be logged in to perform the request. Default is true.
        - priority: If true, sends the request immediately without queueing.
        - wsEventDeduplicationRules: WS events that should be ignored upon receival.
        - progressHandler: A closure to monitor the progress of the request. Useful for tracking upload/download progress.
        - completionHandler: A closure called upon request completion, returning either a decoded response model or an error.

     - Note:
        - `R` must conform to `Decodable` to be used for the expected response model - This means you **have** to implement a completion handler.
        - If the response of the request is unused, declare the result as type of `EmptyResponse` or `DefaultResponse`
     */
    @_spi(SendbirdInternal) public func put<R: Decodable>(
        path: some URLPathConvertible,
        body: RequestParameter = .init(),
        additionalBody: Encodable...,
        multipart: [String: Any] = [:],
        header: [String: String] = [:],
        queryParams: RequestParameter = .init(),
        isSessionRequired: Bool = true,
        isLoginRequired: Bool = true,
        priority: Bool = false,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]? = nil,
        progressHandler: MultiProgressHandler? = nil,
        completionHandler: ((Result<R, AuthError>) -> Void)?
    ) {
        let request = APIRequest<R>(
            method: .put,
            url: path,
            version: "/v3",
            body: body,
            additionalBodies: additionalBody,
            headers: header,
            multipart: multipart,
            queryParameters: queryParams,
            isSessionRequired: isSessionRequired,
            isLoginRequired: isLoginRequired
        )

        if priority {
            self.sendImmediately(
                request: request,
                wsEventDeduplicationRules: wsEventDeduplicationRules,
                progressHandler: progressHandler
            ) { response, error in
                completionHandler?(.init(response, error))
            }
        } else {
            self.send(
                request: request,
                wsEventDeduplicationRules: wsEventDeduplicationRules,
                progressHandler: progressHandler
            ) { response, error in
                completionHandler?(.init(response, error))
            }
        }
    }

    /**
     PATCH API Request

     - Parameters:
        - path: The server endpoint to which the request is made. Accepts any type conforming to `URLPathConvertible`
        - body: The primary content of the request. This is eventually encoded as a dictionary with the specified key value pairs.
        - additionalBody: Additional encodable objects to be included in the request body. `encode(to:)` function will invoked, and will be included in the body payload as a top-level JSON dictionary.
        - multipart: Data for multipart/form-data requests, typically files or binary data, keyed by form field name.
        - header: HTTP headers to include in the request.
        - queryParams: URL query parameters to append to the endpoint.
        - isSessionRequired: Indicates if the request needs session-based authentication. Default is true.
        - isLoginRequired: Indicates if the user must be logged in to perform the request. Default is true.
        - priority: If true, sends the request immediately without queueing.
        - wsEventDeduplicationRules: WS events that should be ignored upon receival.
        - progressHandler: A closure to monitor the progress of the request. Useful for tracking upload/download progress.
        - completionHandler: A closure called upon request completion, returning either a decoded response model or an error.

     - Note:
        - `R` must conform to `Decodable` to be used for the expected response model - This means you **have** to implement a completion handler.
        - If the response of the request is unused, declare the result as type of `EmptyResponse` or `DefaultResponse`
     */
    @_spi(SendbirdInternal) public func patch<R: Decodable>(
        path: some URLPathConvertible,
        body: RequestParameter = .init(),
        additionalBody: Encodable...,
        multipart: [String: Any] = [:],
        header: [String: String] = [:],
        queryParams: RequestParameter = .init(),
        isSessionRequired: Bool = true,
        isLoginRequired: Bool = true,
        priority: Bool = false,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]? = nil,
        progressHandler: MultiProgressHandler? = nil,
        completionHandler: ((Result<R, AuthError>) -> Void)?
    ) {
        let request = APIRequest<R>(
            method: .patch,
            url: path,
            version: "/v3",
            body: body,
            additionalBodies: additionalBody,
            headers: header,
            multipart: multipart,
            queryParameters: queryParams,
            isSessionRequired: isSessionRequired,
            isLoginRequired: isLoginRequired
        )

        if priority {
            self.sendImmediately(
                request: request,
                wsEventDeduplicationRules: wsEventDeduplicationRules,
                progressHandler: progressHandler
            ) { response, error in
                completionHandler?(.init(response, error))
            }
        } else {
            self.send(
                request: request,
                wsEventDeduplicationRules: wsEventDeduplicationRules,
                progressHandler: progressHandler
            ) { response, error in
                completionHandler?(.init(response, error))
            }
        }
    }

    /**
     DELETE API Request

     - Parameters:
        - path: The server endpoint to which the request is made. Accepts any type conforming to `URLPathConvertible`
        - body: The primary content of the request. This is eventually encoded as a dictionary with the specified key value pairs.
        - multipart: Data for multipart/form-data requests, typically files or binary data, keyed by form field name.
        - additionalBody: Additional encodable objects to be included in the request body. `encode(to:)` function will invoked, and will be included in the body payload as a top-level JSON dictionary.
        - header: HTTP headers to include in the request.
        - queryParams: URL query parameters to append to the endpoint.
        - isSessionRequired: Indicates if the request needs session-based authentication. Default is true.
        - isLoginRequired: Indicates if the user must be logged in to perform the request. Default is true.
        - wsEventDeduplicationRules: WS events that should be ignored upon receival.
        - progressHandler: A closure to monitor the progress of the request. Useful for tracking upload/download progress.
        - completionHandler: A closure called upon request completion, returning either a decoded response model or an error.

     - Note:
        - `R` must conform to `Decodable` to be used for the expected response model - This means you **have** to implement a completion handler.
        - If the response of the request is unused, declare the result as type of `EmptyResponse` or `DefaultResponse`
     */
    @_spi(SendbirdInternal) public func delete<R: Decodable>(
        path: some URLPathConvertible,
        body: RequestParameter = .init(),
        multipart: [String: Encodable] = [:],
        additionalBody: Encodable...,
        header: [String: String] = [:],
        queryParams: RequestParameter = .init(),
        isSessionRequired: Bool = true,
        isLoginRequired: Bool = true,
        wsEventDeduplicationRules: [WSEventDeduplicationRule]? = nil,
        progressHandler: MultiProgressHandler? = nil,
        completionHandler: ((Result<R, AuthError>) -> Void)?
    ) {
        let request = APIRequest<R>(
            method: .delete,
            url: path,
            version: "/v3",
            body: body,
            additionalBodies: additionalBody,
            headers: header,
            multipart: multipart,
            queryParameters: queryParams,
            isSessionRequired: isSessionRequired,
            isLoginRequired: isLoginRequired
        )

        self.send(
            request: request,
            wsEventDeduplicationRules: wsEventDeduplicationRules,
            progressHandler: progressHandler
        ) { response, error in
            completionHandler?(.init(response, error))
        }
    }
    
    // MARK: - WebSocket Request Methods
    
    @_spi(SendbirdInternal) public func sendWS<R: Decodable>(
        commandType: CommandType,
        requestId: String?,
        body: RequestParameter = .init(),
        additionalBody: Encodable...,
        completionHandler: ((Result<R, AuthError>) -> Void)?
    ) {
        #if DEBUG
        callSendWSInterceptionIfNeeded(
            commandType,
            requestId,
            additionalBody,
            completionHandler: completionHandler
        )
        #endif

        let request = BaseWSRequest<R>(commandType: commandType, requestId: requestId, body: body, additionalBodies: additionalBody)
        self.send(request: request) { command, error in
            completionHandler?(.init(command, error))
        }
    }

    @_spi(SendbirdInternal) public func sendWS(
        commandType: CommandType,
        requestId: String?,
        body: RequestParameter = .init(),
        additionalBody: Encodable...
    ) {
        let request = BaseWSRequest<DefaultResponse>(
            commandType: commandType,
            requestId: requestId,
            body: body,
            additionalBodies: additionalBody
        )
        self.send(request: request)
    }
    
    #if DEBUG
    var sendWSInterception: (
        (
            CommandType,
            String?,
            [CodeCodingKeys: Encodable],
            [Encodable],
            ((Result<Any, AuthError>) -> Void)?
        ) -> Void
    )?
    
    private func callSendWSInterceptionIfNeeded<R: Decodable>(
        _ commandType: CommandType,
        _ requestId: String?,
        _ body: [CodeCodingKeys: Encodable] = [:],
        _ additionalBody: [Encodable],
        completionHandler: ((Result<R, AuthError>) -> Void)?
    ) {
        guard let sendWSInterception else { return }
        
        sendWSInterception(commandType, requestId, body, additionalBody) { result in
            switch result {
            case .success(let value):
                if let typedValue = value as? R {
                    completionHandler?(.success(typedValue))
                } else {
                    completionHandler?(.failure(AuthClientError.unknownError.asAuthError))
                }
            case .failure(let error):
                completionHandler?(.failure(error))
            }
        }
    }

    private func callSendWSInterceptionIfNeeded<R: Decodable>(
        _ commandType: CommandType,
        _ requestId: String?,
        _ additionalBody: [Encodable],
        completionHandler: ((Result<R, AuthError>) -> Void)?
    ) {
        callSendWSInterceptionIfNeeded(commandType, requestId, [:], additionalBody, completionHandler: completionHandler)
    }
    #endif
    
    @_spi(SendbirdInternal) public func send<R: ResultableWSRequest>(request: R, completion: R.CommandHandler?) {
        let timeout = requestTimeout
        
        service.async { [weak self] in
            guard let self = self else { return }
            
            let timer = SBTimer(
                timeInterval: timeout,
                userInfo: nil,
                onBoard: nil) {
                    completion?(nil, AuthClientError.connectionRequired.asAuthError)
                }
            
            let queueItem: QueuedRequestHandler = {
                guard timer.valid else { return .process }
                
                let processResult = self.wsProcessStrategy(request: request)
                switch processResult {
                case .onHold:
                    return processResult
                case .error(let error):
                    timer.abort()
                    
                    completion?(nil, error)
                    return processResult
                case .process:
                    timer.abort()
                    
                    self.router.send(request: request, completion: completion)
                    return .process
                }
            }
            self.queuedRequests.append(queueItem)
            self.processQueuedRequests()
        }
    }
    
    @_spi(SendbirdInternal) public func send<R: WSRequestable>(request: R) {
        service.async { [weak self] in
            guard let self = self else { return }
            
            self.queuedRequests.append {
                let processResult = self.wsProcessStrategy(request: request)
                switch processResult {
                case .onHold, .error:
                    return processResult
                case .process:
                    self.router.send(request: request)
                    return processResult
                }
            }
            
            self.processQueuedRequests()
        }
    }
        
    @_spi(SendbirdInternal) public func cancelTask(with requestId: String, completionHandler: BoolHandler?) {
        router.cancelTask(with: requestId, completionHandler: completionHandler)
    }
    
    private func processQueuedRequests() {
        service.async { [weak self] in
            guard let self = self else { return }
            self.queuedRequests = self.queuedRequests.filter {
                $0() == .onHold
            }
        }
    }
    
    @_spi(SendbirdInternal) public enum ProcessResult: Equatable {
        case onHold
        case error(AuthError)
        case process
        
        @_spi(SendbirdInternal) public static func == (lhs: ProcessResult, rhs: ProcessResult) -> Bool {
            switch (lhs, rhs) {
            case (.onHold, .onHold): return true
            case (.error, .error): return true
            case (.process, .process): return true
            default: return false
            }
        }
    }
    
    @_spi(SendbirdInternal) public func apiProcessStrategy(request: any APIRequestable) -> ProcessResult {
        if request.isLoginRequired {
            switch sessionValidator?.state {
            case .connected:
                if connectionState is ConnectionStateEvent.Connecting {
                    return .onHold
                }
                
                return .process
            case .refreshing:
                // Postpones process until session refreshed.
                return .onHold
            case nil, .some(.none):
                return .error(AuthClientError.connectionRequired.asAuthError)
            }
        } else {
            return .process
        }
    }
    
    @_spi(SendbirdInternal) public func wsProcessStrategy(request: WSRequestable) -> ProcessResult {
        switch sessionValidator?.state {
        case .connected:
            if connectionState is ConnectionStateEvent.Connecting ||
                connectionState is ConnectionStateEvent.Reconnecting ||
                connectionState is ConnectionStateEvent.ReconnectingStarted {
                return .onHold
            }
            
            if webSocketConnectionState == .open {
                return .process
            } else {
                return .error(AuthClientError.webSocketConnectionClosed.asAuthError)
            }
        case .refreshing:
            // Allow UpdateSessionKeyRequest.WS to be processed as an exception.
            if request.commandType == .login {
                if webSocketConnectionState == .open {
                    return .process
                } else {
                    return .error(AuthClientError.webSocketConnectionClosed.asAuthError)
                }
            }
            
            // Postpones process until session refreshed.
            return .onHold
        case nil, .some(.none):
            return .error(AuthClientError.connectionRequired.asAuthError)
        }
    }
}
// MARK: - EventDelegate

extension RequestQueue: EventDelegate {
    @_spi(SendbirdInternal) public func didReceiveSBCommandEvent(command: SBCommand) async {
        // do-nothing
    }
    
    @_spi(SendbirdInternal) public func didReceiveInternalEvent(command: InternalEvent) {
        if let connectionState = command as? ConnectionStateEventable {
            self.connectionState = connectionState
        }
        
        switch command {
        case is ConnectionStateEvent.InternalDisconnected, is ConnectionStateEvent.ExternalDisconnected, is ConnectionStateEvent.Logout:
            self.processQueuedRequests()
        case is ConnectionStateEvent.SessionRefreshed, is SessionExpirationEvent.Refreshed, is SessionExpirationEvent.RefreshFailed:
            self.processQueuedRequests()
        default: break
        }
    }
}

extension Result {
    @_spi(SendbirdInternal) public init(_ success: Success?, _ failure: Failure?) where Failure == AuthError {
        if let error = failure {
            self = .failure(error)
        } else if let value = success {
            self = .success(value)
        } else {
            self = .failure(AuthClientError.unknownError.asAuthError)
        }
    }
}
