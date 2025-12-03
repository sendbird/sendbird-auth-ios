//
//  Date+SendbirdChat.swift
//  SendbirdChat
//
//  Created by Wooyoung Chung on 10/20/21.
//

import Foundation

@_spi(SendbirdInternal) public extension Date {
    static var now: Date { Date() }
    
    static var yesterday: Date? { Date().dayBefore }
    
    static var tomorrow: Date? { Date().dayAfter }

    var milliSeconds: Int64 {
        Int64(timeIntervalSince1970 * 1000)
    }
    
    init(milliSeconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliSeconds) / 1000)
    }
    
    var seconds: TimeInterval {
        timeIntervalSince1970
    }
    
    func removingSeconds() -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        return calendar.date(from: dateComponents) ?? self
    }
    
    var dayBefore: Date? {
        noon.flatMap { Calendar.current.date(byAdding: .day, value: -1, to: $0) }
    }
    var dayAfter: Date? {
        noon.flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0) }
    }
    var noon: Date? {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }

}
