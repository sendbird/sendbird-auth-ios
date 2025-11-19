//
//  RunLoop+SendBirdTimer.swift
//
//
//  Created by sendbird-young on 17/11/2019.
//
import Foundation

extension RunLoop {
    static var sbtimerRunLoop: RunLoop { self.sharedRunLoop }
    
    private static var sharedRunLoop: RunLoop = {
        SBRunloopThread.shared.safeRunloop
    }()
}

class SBRunloopThread: Thread {
    static var shared: SBRunloopThread = {
        let thread = SBRunloopThread()
        thread.qualityOfService = .userInteractive
        thread.name = "com.sendbird.core.runloop.thread"
        thread.start()
        
        return thread
    }()
    
    var runloop: RunLoop!
    var waitGroup: DispatchGroup
    
    var safeRunloop: RunLoop {
        waitGroup.wait()
        return runloop
    }
    
    private override init() {
        self.waitGroup = DispatchGroup()
        self.waitGroup.enter()
    }
    
    override func main() {
        runloop = RunLoop.current
        waitGroup.leave()
        
        // Add an empty run loop source to prevent runloop from spinning.
        var sourceCtx = CFRunLoopSourceContext(
            version: 0,
            info: nil,
            retain: nil,
            release: nil,
            copyDescription: nil,
            equal: nil,
            hash: nil,
            schedule: nil,
            cancel: nil,
            perform: nil
        )
        
        let source = CFRunLoopSourceCreate(nil, 0, &sourceCtx)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.defaultMode)
        
        while runloop.run(mode: .default, before: NSDate.distantFuture) { }
        assert(false)
    }
}
