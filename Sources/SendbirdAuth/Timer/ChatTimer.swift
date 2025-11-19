//
//  SBTimer.swift
//
//
//  Created by sendbird-young on 17/11/2019.
//
import Foundation

package class SBTimer: NSObject {
    // MARK: Timer
    package var timer: Timer?
    package let userInfo: [String: Any]?
    
    // MARK: Timer Info
    package let identifier: String
    private let queue: SafeSerialQueue

    // MARK: state
    package enum State: String {
        case running = "Running"
        case expired = "Expired"
        case stopped = "Stopped"
    }
    
    private var state: State = .running
    
    // MARK: Expiration
    private(set) var afterExpired: VoidHandler?
    package let repeatable: Bool
    
    package var valid: Bool {
        self.queue.sync {
            self.state == .running
        }
    }
    
    @discardableResult
    package init(
        timeInterval: TimeInterval,
        userInfo: [String: Any]?,
        // SBTimerBoard should not escape init.
        onBoard board: SBTimerBoardDelegate?,
        identifier: String = UUID().uuidString,
        repeats: Bool = false,
        expirationHandler: VoidHandler? = nil
    ) {
        self.userInfo = userInfo
        self.identifier = identifier
        self.queue = SafeSerialQueue(label: "com.sendbird.core.common.timer.\(identifier)")
        self.repeatable = repeats
        
        self.afterExpired = expirationHandler
        
        super.init()
        
        self.timer = Timer(
            timeInterval: timeInterval,
            target: self,
            selector: #selector(expire),
            userInfo: userInfo,
            repeats: repeats
        )
        
        board?.add(timer: self)
        if let timer = self.timer {
            RunLoop.sbtimerRunLoop.add(timer, forMode: .common)
        }
    }
    
    // MARK: Actions
    @objc
    private func expire() {
        queue.sync { [weak self] in
            guard let self else { return }
            if self.repeatable && self.state == .running {
                // repeatable
                DispatchQueue.global(qos: .userInteractive).async {
                    self.afterExpired?()
                }
            } else {
                // not repeatable
                switch state {
                case .running:
                    self.state = .expired
                    DispatchQueue.global(qos: .userInteractive).async {
                        self.afterExpired?()
                        self.afterExpired = nil
                    }
                case .expired: break
                    // do nothing
                case .stopped:
                    break
                    // already handled
                }
                
                self.remove()
            }
        }
    }
    
    @objc
    package func abort() {
        queue.sync { [weak self] in
            guard let self = self else { return }
            if self.state == .running {
                self.state = .stopped
            }
            self.remove()
        }
    }
    
    @objc
    package func stop(completionHandler: ErrorHandler? = nil) {
        queue.sync { [weak self] in
            guard let self = self else { return }
            switch self.state {
            case .stopped:
                DispatchQueue.global(qos: .userInteractive).async {
                    completionHandler?(AuthClientError.timerWasAlreadyDone.asAuthError)
                }
            case .expired:
                DispatchQueue.global(qos: .userInteractive).async {
                    completionHandler?(AuthClientError.timerWasExpired.asAuthError)
                }
            case .running:
                self.state = .stopped
                self.remove()
                DispatchQueue.global(qos: .userInteractive).async {
                    completionHandler?(nil)
                }
            }
        }
    }
    
    private func remove() {
        timer?.invalidate()
    }
}
