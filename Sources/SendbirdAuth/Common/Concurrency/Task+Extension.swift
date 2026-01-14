//
//  Task+Extension.swift
//  SendbirdChat
//
//  Created by Kai Lee on 10/1/25.
//

import Foundation

/// This code is temporarily used until native Task.sleep of iOS 16 becomes available.
@available(iOS, deprecated: 16.0, message: "Use native Task.sleep instead")
extension Task where Success == Never, Failure == Never {
    struct SleepDuration {
        fileprivate let nanoseconds: UInt64

        static func seconds(_ value: TimeInterval) -> SleepDuration {
            return .init(nanoseconds: Self.nanoseconds(from: value))
        }

        static func milliseconds(_ value: TimeInterval) -> SleepDuration {
            return .seconds(value / 1_000)
        }

        static func microseconds(_ value: TimeInterval) -> SleepDuration {
            return .seconds(value / 1_000_000)
        }

        static func nanoseconds(_ value: UInt64) -> SleepDuration {
            return .init(nanoseconds: value)
        }

        private static func nanoseconds(from seconds: TimeInterval) -> UInt64 {
            let clamped = max(0, seconds)
            guard clamped > 0 else { return 0 }

            let rawNanoseconds = clamped * Double(NSEC_PER_SEC)
            let roundedNanoseconds = rawNanoseconds.rounded(.up)
            let capped = min(roundedNanoseconds, Double(UInt64.max))
            return UInt64(capped)
        }
    }

    static func sleep(for duration: SleepDuration) async throws {
        guard duration.nanoseconds > 0 else { return }
        try await Task.sleep(nanoseconds: duration.nanoseconds)
    }
}
