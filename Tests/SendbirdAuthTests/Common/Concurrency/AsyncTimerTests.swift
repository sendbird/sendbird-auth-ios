//
//  AsyncTimerTests.swift
//

import XCTest
@_spi(SendbirdInternal) @testable import SendbirdAuthSDK

final class AsyncTimerTests: XCTestCase {
    private actor TickCounter {
        private var value = 0

        func increment() {
            value += 1
        }

        func current() -> Int {
            value
        }
    }
    
    // MARK: - Test run

    func test_run() async throws {
        let timer = AsyncTimer(timeInterval: 0.05)
        let expectation = XCTestExpectation()

        timer.run(repeats: false) {
            expectation.fulfill()
        }

        var stateAfterStart = await timer.state
        if stateAfterStart == .pending {
            for _ in 0..<3 {
                try? await Task.sleep(nanoseconds: 5_000_000)
                stateAfterStart = await timer.state
                if stateAfterStart != .pending { break }
            }
        }

        XCTAssertNotEqual(stateAfterStart, .pending)

        await fulfillment(of: [expectation], timeout: 1.0)
        let stateAfterRun = await timer.state
        XCTAssertEqual(stateAfterRun, .expired)
    }

    func test_repeatingRun() async {
        let timer = AsyncTimer(timeInterval: 0.05)
        let expectedTickCount = 3
        let expectation = XCTestExpectation()
        expectation.expectedFulfillmentCount = expectedTickCount

        let ticks = TickCounter()
        timer.run(repeats: true) {
            await ticks.increment()
            if await ticks.current() <= expectedTickCount {
                expectation.fulfill()
            }
            if await ticks.current() == expectedTickCount {
                await timer.abort()
            }
        }

        await fulfillment(of: [expectation], timeout: 10)
        let stateAfterAbort = await timer.state
        XCTAssertEqual(stateAfterAbort, .stopped)
    }

    // MARK: - Test stop
    
    func test_stop_fromPendingTransitionsToStopped() async throws {
        let timer = AsyncTimer(timeInterval: 0.1)

        try await timer.stop()

        let state = await timer.state
        XCTAssertEqual(state, .stopped)
    }

    func test_stop_whileRunningThrowsWhenRepeated() async throws {
        let timer = AsyncTimer(timeInterval: 0.2)

        timer.run(repeats: true) {}

        var currentState: AsyncTimer.State = .pending
        for _ in 0..<10 {
            currentState = await timer.state
            if currentState == .running { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(currentState, .running)

        try await timer.stop()
        let stateAfterFirstStop = await timer.state
        XCTAssertEqual(stateAfterFirstStop, .stopped)

        do {
            try await timer.stop()
            XCTFail("Expected alreadyStopped error")
        } catch let error {
            guard case .timerWasAlreadyDone = error else {
                return XCTFail("Unexpected AsyncTimerError: \(error)")
            }
        }
    }

    func test_abort_preventsFirstTickAndStopsTimer() async throws {
        let timer = AsyncTimer(timeInterval: 0.1)
        let counter = TickCounter()

        timer.run(repeats: true) {
            await counter.increment()
        }

        var state: AsyncTimer.State = .pending
        for _ in 0..<10 {
            state = await timer.state
            if state == .running { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(state, .running)

        await timer.abort()

        try await Task.sleep(nanoseconds: 200_000_000)

        let tickCount = await counter.current()
        XCTAssertEqual(tickCount, 0)

        let stateAfterAbort = await timer.state
        XCTAssertEqual(stateAfterAbort, .stopped)

        await timer.abort()
        let stateAfterRepeatedAbort = await timer.state
        XCTAssertEqual(stateAfterRepeatedAbort, .stopped)
    }
}
