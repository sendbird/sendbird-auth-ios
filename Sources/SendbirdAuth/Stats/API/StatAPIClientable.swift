//
//  StatAPIClientable.swift
//  SendbirdChatTests
//
//  Created by Ernest Hong on 2022/06/02.
//

import Foundation

package protocol StatAPIClientable: AnyObject {
    func setDeviceId(deviceId: String)
    func send<RecordStatType: BaseStatType>(stats: [RecordStatType]) async throws
    func sendNotificationStats(stats: [NotificationStat]) async throws
#if TESTCASE
    func setMockResult(enabled: Bool, error: AuthError?)
#endif
}


