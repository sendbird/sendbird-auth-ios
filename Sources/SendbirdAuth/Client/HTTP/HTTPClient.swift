//
//  HTTPClient.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

@_spi(SendbirdInternal) public protocol HTTPClientInterface: NSObject, Injectable {
    var routerConfig: CommandRouterConfiguration { get set }
    func prefetch()
    func clear()
    func send<R: APIRequestable>(
        multipartRequest request: R,
        headers: [String: String],
        progressHandler: MultiProgressHandler?,
        completionHandler: R.CommandHandler?
    )
    func send<R: APIRequestable>(
        request: R,
        headers: [String: String],
        completionHandler: R.CommandHandler?
    )
    func cancelUpload(with requestId: String, completionHandler: BoolHandler?)
    // The unit is bytes.
    var uploadSizeLimit: Int64 { get set }
    var sharedContainerIdentifier: String? { get set }
    
    func registerObservers(identifier: String)
}

@_spi(SendbirdInternal) public class HTTPClient: NSObject, HTTPClientInterface, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    @_spi(SendbirdInternal) public struct Constants {
        @_spi(SendbirdInternal) public static let queueName = "com.sendbird.core.networking.queue"
        @_spi(SendbirdInternal) public static let boundary = "uwhQ9Ho7y873Ha"
        @_spi(SendbirdInternal) public static let newline = "\r\n"
        @_spi(SendbirdInternal) public static let fileUploadTimeout: Double = 60 // timesout after 60s
    }
    
    // MARK: Injectable
    @DependencyWrapper var dependency: Dependency?
    @_spi(SendbirdInternal) public var config: SendbirdConfiguration? { dependency?.config }
    private var statManager: StatManager? { dependency?.statManager }
    private var connectionManager: DeviceConnectionManager? { dependency?.deviceConnectionManager }

    @_spi(SendbirdInternal) public var routerConfig: CommandRouterConfiguration

    @_spi(SendbirdInternal) public var delegateQueue: OperationQueue
    @_spi(SendbirdInternal) public var uploadSizeLimit: Int64 = .max
    
    @_spi(SendbirdInternal) public var sharedContainerIdentifier: String?
    
    @_spi(SendbirdInternal) public var canceledRequests: [String: Bool] = [:] // Request Id : Canceled Status
    @_spi(SendbirdInternal) public var uploadTasks: [String: Int] = [:] // Request Id : Upload Task ID
    @_spi(SendbirdInternal) public var backgroundTasks: [Int: URLBackgroundTask] = [:] // Upload Task ID: Upload Task
    private var cancellableTasks: SafeDictionary<String, URLSessionSafeCancellableDataTask> = [:] // UUID: URLCancellableTask
    
    @_spi(SendbirdInternal) public lazy var backgroundURLSession: URLSession = {
        return createBackgroundURLSession()
    }()
    
    private var urlSession: URLSession
    
    @_spi(SendbirdInternal) public init(routerConfig: CommandRouterConfiguration) {
        let queue = OperationQueue()
        queue.name = "com.sendbird.core.networking.http"
        queue.maxConcurrentOperationCount = 10
        
        self.routerConfig = routerConfig
        self.delegateQueue = queue
        
        urlSession = Self.createURLSession()
    }
    
    @_spi(SendbirdInternal) public func getBackgroundURLSessionConfig() -> URLSessionConfiguration {
        return self.backgroundURLSession.configuration
    }
    
    @_spi(SendbirdInternal) public func createBackgroundURLSession() -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: "com.sendbird.core.networking.background_session.\(UUID().uuidString)")
        config.sharedContainerIdentifier = sharedContainerIdentifier
        config.sessionSendsLaunchEvents = true
        config.isDiscretionary = false
        config.requestCachePolicy = .reloadIgnoringCacheData
        config.urlCache = nil
        
        return URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
    }
    
    private func createURLRequest(request: any APIRequestable) -> URLRequest? {
        return request.urlRequest(baseURL: routerConfig.apiHost)
    }
    
    @_spi(SendbirdInternal) public func send<R: APIRequestable>(
        request: R,
        headers: [String: String] = [:],
        completionHandler: R.CommandHandler? = nil
    ) {
        guard var urlRequest = createURLRequest(request: request) else {
            completionHandler?(nil, AuthCoreError.requestFailed.asAuthError)
            return
        }
        
        urlRequest = buildHeader(
            with: urlRequest,
            underlyingRequest: request,
            headers: headers
        )
        
        Logger.http.debug(
            """
            [Request] \(String(reflecting: type(of: request)))
            \(urlRequest.logDescription)
            """
        )
        
        let requestAt = Date().milliSeconds
        let requestId = UUID().uuidString
        let dataTask = urlSession.safeCancellableDataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self,
                  let decoder = self.dependency?.decoder else {
                completionHandler?(nil, AuthClientError.connectionCanceled.asAuthError)
                return
            }

            self.cancellableTasks.remove(forKey: requestId)
            
            Logger.http.info("[Sendbird] Finish HTTP session: \(NSDate().timeIntervalSince1970)")
            
            guard error == nil else {
                if (error as? NSError)?.code != URLError.Code.cancelled.rawValue {
                    completionHandler?(nil, AuthCoreError.networkError.asAuthError)
                } else {
                    completionHandler?(nil, AuthCoreError.requestFailed.asAuthError)
                }
                return
            }
            
            guard let httpURLResponse = response as? HTTPURLResponse,
                  let data = data else {
                completionHandler?(nil, AuthCoreError.malformedData.asAuthError)
                return
            }
            
            let responseAt = Date().milliSeconds
            let succeeded = (200..<300).contains(httpURLResponse.statusCode)
            let errorCode = succeeded ? nil : AuthError.error(from: data).code
            let apiResultStat = APIResultStat(
                endpoint: urlRequest.url?.absoluteString ?? "",
                method: request.method.rawValue,
                latency: responseAt - requestAt,
                success: succeeded,
                errorCode: errorCode,
                errorDescription: error?.localizedDescription
            )
            
            self.statManager?.append(apiResultStat, fromAuth: false, completion: nil)
            
            Logger.http.debug("[Response] [\(urlRequest.httpMethod ?? request.method.rawValue)] \(String(reflecting: type(of: request))) with\n\(data.prettyPrintedJSONString)")
            
            switch httpURLResponse.statusCode {
            case 200..<300:
                let result = request.decodeResult(from: data, decoder: decoder)
                switch result {
                case .success(let value):
                    completionHandler?(value, nil)
                case .failure(let error):
                    completionHandler?(nil, error)
                }
            case 400..<500:
                let error = self.routerConfig.exceptionParser.parse(data: data)
                    ?? AuthError.error(from: data)
                completionHandler?(nil, error)
            default:
                completionHandler?(nil, AuthClientError.internalServerError.asAuthError)
            }
        } cancelCompletion: {
            completionHandler?(nil, AuthClientError.connectionCanceled.asAuthError)
        }
            
        cancellableTasks[requestId] = dataTask
        dataTask.resume()
    }
    
    @_spi(SendbirdInternal) public func send(urlRequest: URLRequest, completionHandler: AnyResponseHandler?) {
        let dataTask = urlSession.dataTask(with: urlRequest as URLRequest) { (data, response, error) in
            guard error == nil else {
                if (error as? NSError)?.code != URLError.Code.cancelled.rawValue {
                    completionHandler?(nil, AuthCoreError.networkError.asAuthError)
                } else {
                    completionHandler?(nil, AuthCoreError.requestFailed.asAuthError)
                }
                return
            }
            
            guard let httpURLResponse = response as? HTTPURLResponse,
                  let data = data else {
                completionHandler?(nil, AuthCoreError.malformedData.asAuthError)
                return
            }
            
            let result = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
            
            switch httpURLResponse.statusCode {
            case 200..<300:
                completionHandler?(result, nil)
            case 400..<500:
                let error = self.routerConfig.exceptionParser.parse(data: data)
                    ?? AuthError.error(from: data)
                completionHandler?(nil, error)
            default:
                completionHandler?(nil, AuthCoreError.internalServerError.asAuthError)
            }
        }
        dataTask.resume()
    }

    @_spi(SendbirdInternal) public func send<R: APIRequestable>(
        multipartRequest request: R,
        headers: [String: String] = [:],
        progressHandler: MultiProgressHandler? = nil,
        completionHandler: R.CommandHandler? = nil
    ) {
        guard var urlRequest = request.urlRequest(baseURL: routerConfig.apiHost) else {
            Logger.http.verbose("Failed with canceled file upload")
            completionHandler?(nil, AuthCoreError.requestFailed.asAuthError)
            return
        }
        
//        if let fileSize = request.fileSize, fileSize > uploadSizeLimit {
//            completionHandler?(nil, AuthCoreError.fileSizeLimitExceeded.asAuthError)
//            return
//        }
        
        let (body, requestId) = request.multipartBody()
        
        if let requestId = requestId, canceledRequests[requestId] == true {
            canceledRequests.removeValue(forKey: requestId)
            completionHandler?(nil, AuthCoreError.fileUploadCanceled.asAuthError)
            return
        }
        
        urlRequest = buildHeader(
            with: urlRequest,
            underlyingRequest: request,
            headers: headers
        )
        
        urlRequest.setValue("multipart/form-data; boundary=\(HTTPClient.Constants.boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(String(body?.count ?? 0), forHTTPHeaderField: "Content-Length")
        
        let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        do {
            try body?.write(to: fileURL)
        } catch {
            completionHandler?(nil, AuthCoreError.fileUploadCanceled.asAuthError)
            return
        }
        
        let task = backgroundURLSession.uploadTask(with: urlRequest, fromFile: fileURL)
        
        let backgroundTask = URLBackgroundTask(
            dependency: self.dependency,
            requestId: requestId,
            backgroundTask: task,
            transferTimeout: config?.transferTimeout ?? SendbirdConfiguration.transferTimeoutDefault,
            progressTask: progressHandler) { (data, error) in
                guard let data = data, error == nil else {
                    completionHandler?(nil, error)
                    return
                }

                let result = request.decodeResult(
                    from: data,
                    decoder: self.dependency?.decoder ?? JSONDecoder()
                )
                
                switch result {
                case .success(let value):
                    completionHandler?(value, nil)
                case .failure(let error):
                    completionHandler?(nil, error)
                }
        }
        
        self.backgroundTasks[task.taskIdentifier] = backgroundTask
        
        if let requestId = requestId {
            self.uploadTasks[requestId] = task.taskIdentifier
            self.canceledRequests.removeValue(forKey: requestId)
        }
        
        backgroundTask.start()
    }
    
    @_spi(SendbirdInternal) public func buildHeader<R: APIRequestable>(
        with request: URLRequest,
        underlyingRequest: R,
        headers: [String: String] = [:]
    ) -> URLRequest {
        var request = request
        
        underlyingRequest.headers.forEach({
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        })
        
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }
    
    @_spi(SendbirdInternal) public func cancelUpload(with requestId: String, completionHandler: BoolHandler?) {
        if let taskID = uploadTasks[requestId],
           let backgroundTask = backgroundTasks[taskID] {
            backgroundTask.abort()
            completionHandler?(true, nil)
        } else if canceledRequests[requestId] != nil {
            canceledRequests[requestId] = true
            completionHandler?(true, nil)
        } else {
            completionHandler?(false, AuthCoreError.fileUploadCancelFailed.asAuthError)
        }
    }
    
    @_spi(SendbirdInternal) public func addWaitingForUpload(with requestId: String) {
        canceledRequests[requestId] = false
    }
    
    // reduce TLS handshaking time for later api calls
    @_spi(SendbirdInternal) public func prefetch() {
        let request = DummyRequest()
        guard var urlRequest = request.urlRequest(baseURL: routerConfig.apiHost) else { return }
        urlRequest = buildHeader(
            with: urlRequest,
            underlyingRequest: request
        )
        // TODO: Check if empty session is okay for prefetch
        // P3
        let task = urlSession.dataTask(with: urlRequest)
        task.resume()
    }
        
    @_spi(SendbirdInternal) public func clear() {
        // 1. Cancel all tasks (~ oldSession)
        cancellableTasks.values.forEach { $0.cancel() }
        backgroundTasks.values.forEach { $0.abort() }
        uploadTasks.forEach { cancelUpload(with: $0.key, completionHandler: nil) }
        
        // 2. RemoveAll Tasks (block new request)
        cancellableTasks.removeAll()
        backgroundTasks.removeAll()
        uploadTasks.removeAll()
        
        // 3. Create new session and replace
        let newSession = Self.createURLSession()
        let oldSession = urlSession
        urlSession = newSession
        
        // 4. oldSession invalidate
        DispatchQueue.global().async {
            oldSession.invalidateAndCancel()
        }
    }
    
    @_spi(SendbirdInternal) public func registerObservers(identifier: String) {
        
    }
    
    private static func createURLSession() -> URLSession {
        let urlConfig = URLSessionConfiguration.default
        urlConfig.requestCachePolicy = .reloadIgnoringCacheData
        urlConfig.urlCache = nil
        
        return URLSession(configuration: urlConfig)
    }
    
    @_spi(SendbirdInternal) public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Logger.http.info("All tasks are finished.")
    }
    
    @_spi(SendbirdInternal) public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Logger.http.info("url session data task received data. task id: \(dataTask.taskIdentifier)")
        self.backgroundTasks[dataTask.taskIdentifier]?.data = data
    }
    
    @_spi(SendbirdInternal) public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Logger.http.info("url session task completed. task id: \(task.taskIdentifier)")
        
        guard let backgroundTask = self.backgroundTasks[task.taskIdentifier] else {
            return
        }
        
        backgroundTask.finish(response: task.response, error: error)
    }
    
    @_spi(SendbirdInternal) public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        Logger.http.info("url session task progress. task id: \(task.taskIdentifier)")
        guard let backgroundTask = self.backgroundTasks[task.taskIdentifier] else {
            return
        }
        
        Logger.http.info("URLBackgroundTask identifier: \(backgroundTask.backgroundTask.taskIdentifier)")
        backgroundTask.triggerProgress(
            bytesSent: bytesSent,
            totalBytesSent: totalBytesSent,
            totalBytesExpectedToSend: totalBytesExpectedToSend
        )
    }
    
    // MARK: Injectable
    @_spi(SendbirdInternal) public func resolve(with dependency: (any Dependency)?) {
        self.dependency = dependency
    }
}

@_spi(SendbirdInternal) public class URLCancellableTask {
    @_spi(SendbirdInternal) public let task: URLSessionTask
    @_spi(SendbirdInternal) public var cancelCompletion: VoidHandler?
    
    @_spi(SendbirdInternal) public init(task: URLSessionTask, cancelCompletion: @escaping VoidHandler) {
        self.task = task
        self.cancelCompletion = cancelCompletion
    }
    
    @_spi(SendbirdInternal) public func cancel() {
        if task.state == .running {
            task.cancel()
        }
        cancelCompletion?()
        cancelCompletion = nil
    }
}

@_spi(SendbirdInternal) public class URLBackgroundTask {
    @_spi(SendbirdInternal) public var isFinished: Bool = false
    
    @ImmutableDependencyWrapper private(set) var dependency: Dependency?
    private var connectionManager: DeviceConnectionManager? { dependency?.deviceConnectionManager }
    
    @_spi(SendbirdInternal) public var requestId: String?
    @_spi(SendbirdInternal) public var data: Data?
    
    @_spi(SendbirdInternal) public var backgroundTask: URLSessionUploadTask
    @_spi(SendbirdInternal) public var transferTimeout: TimeInterval
    
    @_spi(SendbirdInternal) public var progressTask: MultiProgressHandler?
    
    @_spi(SendbirdInternal) public var completionTask: DataResponseHandler?
    
    @_spi(SendbirdInternal) public var timerQueue: DispatchQueue  // A serial queue that updates the timer.
    
    // A timer that times out if URLSessionUploadTask has no progress for 60 seconds.
    @_spi(SendbirdInternal) public lazy var timer: Timer = {
        let timer = Timer(
            timeInterval: transferTimeout,
            target: self,
            selector: #selector(didTimerExpired),
            userInfo: nil,
            repeats: false
        )
        return timer
    }()
    
    init(
        dependency: Dependency?,
        requestId: String?,
        backgroundTask: URLSessionUploadTask,
        transferTimeout: TimeInterval,
        progressTask: MultiProgressHandler?,
        completionTask: DataResponseHandler?
    ) {
        self.requestId = requestId
        self.backgroundTask = backgroundTask
        self.transferTimeout = transferTimeout
        self.progressTask = progressTask
        self.completionTask = completionTask
        self.timerQueue = DispatchQueue(label: "com.sendbird.chat.background.task.timer.\(UUID().uuidString)")
        self.dependency = dependency
    }
    
    @_spi(SendbirdInternal) public func start() {
        // Start the timer.
        timerQueue.async { [weak self] in
            guard let self = self else { return }
            
            let runLoop = RunLoop.current
            runLoop.add(self.timer, forMode: .default)
            runLoop.run()
        }
        
        backgroundTask.resume()
    }
    
    @_spi(SendbirdInternal) public func abort() {
        backgroundTask.cancel()
    }
    
    @_spi(SendbirdInternal) public func triggerProgress(bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard isFinished == false else { return }
        
        // Restart the timer everytime we get a progress update for the URLSessionUploadTask.
        timerQueue.async { [weak self] in
            guard let self = self else { return }

            self.timer.invalidate()
            
            self.timer = Timer(
                timeInterval: self.transferTimeout,
                target: self,
                selector: #selector(self.didTimerExpired),
                userInfo: nil,
                repeats: false
            )
            let runLoop = RunLoop.current
            runLoop.add(self.timer, forMode: .default)
            runLoop.run()
        }
        
        progressTask?(requestId, bytesSent, totalBytesSent, totalBytesExpectedToSend)
    }
    
    @_spi(SendbirdInternal) public func finish(response: URLResponse?, error: Error?) {
        guard isFinished == false else { return }
        
        isFinished = true
        
        timerQueue.async { [weak self] in
            guard let self = self else { return }
            self.timer.invalidate()
        }
        
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled {
                completionTask?(nil, AuthCoreError.fileUploadCanceled.asAuthError)
            } else if (error as NSError).code == NSURLErrorTimedOut {
                if self.connectionManager?.isOffline == true {
                    completionTask?(nil, AuthCoreError.fileUploadTimeoutByNetwork.asAuthError)
                } else {
                    completionTask?(nil, AuthCoreError.fileUploadTimeout.asAuthError)
                }
            } else {
                completionTask?(nil, AuthCoreError.networkError.asAuthError)
            }
            return
        }
        
        guard let data = data,
              let response = response as? HTTPURLResponse else {
            completionTask?(nil, AuthCoreError.malformedData.asAuthError)
            return
        }
        
        Logger.http.info("url session task completed. statusCode: \(response.statusCode)")
        switch response.statusCode {
        case 200..<300:
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
               let dictionary = jsonObject as? [String: Any] {
                Logger.http.info("url session task completed. response: \(dictionary)")
            }
            completionTask?(data, nil)
        case 400..<500:
            completionTask?(nil, .error(from: data))
        case 500...:
            completionTask?(nil, AuthCoreError.internalServerError.asAuthError)
        default:
            completionTask?(nil, AuthCoreError.malformedData.asAuthError)
        }
    }
    
    @objc
    @_spi(SendbirdInternal) public func didTimerExpired() {
        guard isFinished == false else { return }
        
        Logger.http.info("backgroundTask expired.")
        backgroundTask.cancel()
        isFinished = true
        
        if self.connectionManager?.isOffline == true {
            completionTask?(nil, AuthCoreError.fileUploadTimeoutByNetwork.asAuthError)
        } else {
            completionTask?(nil, AuthCoreError.fileUploadTimeout.asAuthError)
        }
    }
}

class URLSessionSafeCancellableDataTask {
    private let lock = NSLock()
    private var dataTask: URLSessionDataTask?
    private weak var urlSession: URLSession?
    private let request: URLRequest
    private var completionHandler: ((Data?, URLResponse?, Error?) -> Void)?
    private var cancelCompletion: VoidHandler?
    
    private enum State {
        case created, running, cancelled, completed
    }
    private var state: State = .created

    init(urlSession: URLSession, request: URLRequest, completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void), cancelCompletion: @escaping VoidHandler) {
        self.urlSession = urlSession
        self.completionHandler = completionHandler
        self.cancelCompletion = cancelCompletion
        self.request = request
    }
    
    func resume() {
        var taskToResume: URLSessionDataTask?
        
        self.lock.lock()
        
        // 이미 시작됐거나 취소된 경우 무시
        guard self.state == .created else {
            self.lock.unlock()
            return
        }

        // task 생성 (completion handler는 아직 실행 안됨)
        let task = urlSession?.dataTask(with: request) { [weak self] data, response, error in
            self?.handleTaskCompletion(data: data, response: response, error: error)
        }
        
        self.dataTask = task
        self.state = .running
        taskToResume = task
        
        self.lock.unlock()

        // lock 밖에서 실제 resume
        taskToResume?.resume()
    }
    
    func cancel() {
        var taskToCancel: URLSessionDataTask?
        var cancelHandler: VoidHandler?
        
        self.lock.lock()
        
        // 이미 취소됐거나 완료된 경우 무시
        guard self.state == .created || self.state == .running else {
            self.lock.unlock()
            return
        }
        
        self.state = .cancelled
        taskToCancel = self.dataTask
        cancelHandler = self.cancelCompletion
        
        // handler들 정리
        self.completionHandler = nil
        self.cancelCompletion = nil
        
        self.lock.unlock()
        
        // lock 밖에서 실제 cancel 및 callback
        taskToCancel?.cancel()
        cancelHandler?()
    }
    
    private func handleTaskCompletion(data: Data?, response: URLResponse?, error: Error?) {
        var handler: ((Data?, URLResponse?, Error?) -> Void)?
        
        self.lock.lock()
        
        // 이미 취소됐거나 완료된 경우 무시
        guard self.state == .running else {
            self.lock.unlock()
            return
        }
        
        self.state = .completed
        handler = self.completionHandler
        
        // handler들 정리
        self.completionHandler = nil
        self.cancelCompletion = nil
        
        self.lock.unlock()
        
        // lock 밖에서 실제 completion callback
        handler?(data, response, error)
    }
}

extension URLSession {
    func safeCancellableDataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void,
        cancelCompletion: @escaping VoidHandler
    ) -> URLSessionSafeCancellableDataTask {
        let safeDataTask = URLSessionSafeCancellableDataTask(
            urlSession: self,
            request: request,
            completionHandler: completionHandler,
            cancelCompletion: cancelCompletion
        )
        
        return safeDataTask
    }
}

#if DEBUG
extension HTTPClient {
    @_spi(SendbirdInternal) public var dependencyForTest: Dependency? { dependency }

    @_spi(SendbirdInternal) public func createUrlRequestForTest(request: any APIRequestable) -> URLRequest? {
        return createURLRequest(request: request)
    }

    @_spi(SendbirdInternal) public func setURLSessionForTest(_ session: URLSession) {
        self.urlSession = session
    }

    @_spi(SendbirdInternal) public func markDependencyResolvedForTest() {
        _dependency.isResolved = true
    }
}
#endif
