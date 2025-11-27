//
//  NotificationStat.swift
//  SendbirdChatSDK
//
//  Created by Ernest Hong on 2023/04/07.
//

import Foundation

@_spi(SendbirdInternal) public final class NotificationStat: NotificationRecordStat {
    @_spi(SendbirdInternal) public override var description: String {
        """
        NotificationStat(action: \(action), templateKey: \(templateKey), channelURL: \(channelURL), tags: \(tags), messageId: \(messageId), source: \(source), messageTs: \(messageTs), topic: \(String(describing: topic)), notificationEventDeadline: \(notificationEventDeadline)
        """
    }
    
    @_spi(SendbirdInternal) public enum CodingKeys: String, CodingKey {
        case action
        case templateKey = "template_key"
        case channelURL = "channel_url"
        case tags
        case messageId = "message_id"
        case source
        case messageTs = "message_ts"
        case topic
        case notificationEventDeadline = "notification_event_deadline"
    }
    
    @_spi(SendbirdInternal) public let action: String
    @_spi(SendbirdInternal) public let templateKey: String
    @_spi(SendbirdInternal) public let channelURL: String
    @_spi(SendbirdInternal) public let tags: [String]
    @_spi(SendbirdInternal) public let messageId: Int64
    @_spi(SendbirdInternal) public let source: String
    @_spi(SendbirdInternal) public let messageTs: Int64
    @_spi(SendbirdInternal) public let topic: String?
    @_spi(SendbirdInternal) public let notificationEventDeadline: Int64
    
    @_spi(SendbirdInternal) public init(
        action: String,
        templateKey: String,
        channelURL: String,
        tags: [String],
        messageId: Int64,
        source: String,
        messageTs: Int64,
        timestamp: Int64 = Date().milliSeconds,
        topic: String? = nil,
        notificationEventDeadline: Int64 = 0
    ) {
        self.action = action
        self.templateKey = templateKey
        self.channelURL = channelURL
        self.tags = tags
        self.messageId = messageId
        self.source = source
        self.messageTs = messageTs
        self.topic = topic
        self.notificationEventDeadline = notificationEventDeadline
        
        super.init(statType: .notificationStats, timestamp: timestamp)
    }
    
    @_spi(SendbirdInternal) public required init(from decoder: Decoder) throws {
        let container = try Self.nestedDecodeContainer(decoder: decoder, keyedBy: CodingKeys.self)
        
        action = try container.decode(String.self, forKey: .action)
        templateKey = try container.decode(String.self, forKey: .templateKey)
        channelURL = try container.decode(String.self, forKey: .channelURL)
        tags = try container.decode([String].self, forKey: .tags)
        messageId = try container.decode(Int64.self, forKey: .messageId)
        source = try container.decode(String.self, forKey: .source)
        messageTs = try container.decode(Int64.self, forKey: .messageTs)
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        notificationEventDeadline = try container.decodeIfPresent(Int64.self, forKey: .notificationEventDeadline) ?? 0
        
        try super.init(from: decoder)
    }

    @_spi(SendbirdInternal) public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = nestedEncodeContainer(encoder: encoder, keyedBy: CodingKeys.self)
        
        try container.encode(action, forKey: .action)
        try container.encode(templateKey, forKey: .templateKey)
        try container.encode(channelURL, forKey: .channelURL)
        try container.encode(tags, forKey: .tags)
        try container.encode(messageId, forKey: .messageId)
        try container.encode(source, forKey: .source)
        try container.encode(messageTs, forKey: .messageTs)
        try container.encodeIfPresent(topic, forKey: .topic)
        try container.encode(notificationEventDeadline, forKey: .notificationEventDeadline)
    }
}
