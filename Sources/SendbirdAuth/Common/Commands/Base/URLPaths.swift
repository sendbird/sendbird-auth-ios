///
///  URLPaths.swift
///  SendbirdChatSDK
///
///  Created by Minhyuk Kim on 2024", "02", "16.
///

import Foundation

public enum URLPaths {
    
    /// Secret", "Application Settings
    case secretApplicationAttrsReactions(applicationId: String)
    case secretApplicationAttrs(applicationId: String)
    case secretApplicationPlan(applicationId: String)
    case secretApplicationUiKitConfiguration(applicationId: String)
    case secretApplicationNotificationChannels(applicationId: String)
    case applicationsSettingsGlobal
    
    /// User Related
    case users(userId: String? = nil)
    case usersToken(userId: String)
    case usersLogin(userId: String)
    case usersSessionKey(userId: String)
    case usersPushTemplate(userId: String)
    case usersPushApns(userId: String, token: String? = nil)
    case usersPushDeviceTokens(userId: String, pushTokenType: String)
    case usersPush(userId: String)
    case usersUnreadMessageCount(userId: String)
    case usersUnreadNotificationCount(userId: String)
    case usersUnreadItemCount(userId: String)
    case usersUnreadChannelCount(userId: String)
    case usersCountPreference(userId: String, channelURL: String)
    case usersMarkAsReadAll(userId: String)
    case usersAllowFriendDiscovery(userId: String)
    case usersChannelInvitationPreference(userId: String)
    case usersMetadata(userId: String, key: String? = nil)
    case usersFriends(userId: String)
    case usersFriendDiscoveries(userId: String)
    case usersFriendChangelogs(userId: String)
    
    case usersPushPreference(userId: String, channelURL: String? = nil)
    case usersMyGroupChannels(userId: String)
    case usersMyGroupChannelsChangelogs(userId: String)
    case usersMyGroupChannelsMembersChangelogs(userId: String)
    case usersBlock(blockerUserId: String, targetUserId: String? = nil)
    case usersGroupChannelCount(userId: String)
    
    /// Group Channels
    case groupChannels(_ channelURL: String? = nil)
    case groupChannelsTyping(channelURL: String)
    case groupChannelsMessagesMarkAsDelivered(channelURL: String)
    case groupChannelsMessagesInReviewTransitions(channelURL: String, messageId: Int64)
    case groupChannelsDistinctMessage
    case groupChannelsMessagesMarkAsRead(channelURL: String)
    case groupChannelsMembers(channelURL: String)
    case groupChannelsHide(channelURL: String)
    case groupChannelsInvite(channelURL: String)
    case groupChannelsDecline(channelURL: String)
    case groupChannelsAccept(channelURL: String)
    case groupChannelsJoin(channelURL: String)
    case groupChannelsLeave(channelURL: String)
    case groupChannelsResetUserHistory(channelURL: String)
    case groupChannelsScreenshot(channelURL: String)
    case groupChannelsMessagesFeedbacks(channelURL: String, messageId: Int64, feedbackId: Int64? = nil)
    
    /// Channel Type Specific Operations
    case channelMessages(channelType: AuthChannelType, channelURL: String, messageId: Int64? = nil)
    case channelMessagesChangelogs(channelType: AuthChannelType, channelURL: String)
    case channelScheduledMessages(channelType: AuthChannelType, channelURL: String, scheduledMessageId: Int64? = nil)
    case channelScheduledMessagesSendNow(channelType: AuthChannelType, channelURL: String, scheduledMessageId: Int64)
    case channelMessagesPin(channelType: AuthChannelType, channelURL: String, messageId: Int64)
    case channelMetacounter(channelType: AuthChannelType, channelURL: String, key: String? = nil)
    case channelOperators(channelType: AuthChannelType, channelURL: String)
    case channelMessagesSortedMetaArray(channelType: AuthChannelType, channelURL: String, messageId: Int64)
    case channelMetadata(channelType: AuthChannelType, channelURL: String, key: String? = nil)
    case channelBan(channelType: AuthChannelType, channelURL: String, userId: String? = nil)
    case channelFreeze(channelType: AuthChannelType, channelURL: String)
    case channelMute(channelType: AuthChannelType, channelURL: String, userId: String? = nil)
    case channelMessagesReactions(channelType: AuthChannelType, channelURL: String, messageId: Int64)
    case channelMessagesTranslation(channelType: AuthChannelType, channelURL: String, messageId: Int64)
    case channelPinnedMessages(channelType: AuthChannelType, channelURL: String)
    case channelMessagePurgeOffset(channelURL: String)

    /// Notifications and Templates
    case notificationsChannels(channelKey: String)
    case notificationsChannelsCategories(channelKey: String, categoryId: String)
    case notificationsSettings
    case notificationsTemplates(key: String? = nil)
    
    /// Bots
    case bots(botId: String)
    case botsSend(botUserId: String)
    
    /// Custom Responses
    case customResponses
    
    case scheduledMessagesCount
    
    case searchMessages
    
    /// Polls
    case pollsVote(pollId: Int64)
    case pollsClose(pollId: Int64)
    case polls(pollId: Int64? = nil)
    case pollsOptions(pollId: Int64, pollOptionId: Int64? = nil)
    case pollsChangelogs(channelType: AuthChannelType, channelURL: String)
    case pollsOptionsVoters(pollId: Int64, pollOptionId: Int64)
    
    /// Reporting
    case reportUsers(reportedUserId: String)
    case reportChannel(channelType: AuthChannelType, channelURL: String)
    case reportChannelMessage(channelType: AuthChannelType, channelURL: String, messageId: Int64)
    case reportCategory

    /// Open Channels
    case openChannels(_ channelURL: String? = nil)
    case openChannelsParticipants(channelURL: String)
    
    /// Emojis and Categories
    case emojis(emojiKey: String)
    case emojiCategories(categoryId: Int64? = nil)
    
    case storageFile
    
    /// Form
    case formsSubmit(formId: Int64)
    
    case forms
    case formsId(formId: Int)
    
    /// Workflows
    case workflows(workflowId: Int?)
    
    /// AuthAIAgent
    case messengerSettings(aiAgentId: String)
    case aiAgentContext(aiAgentId: String, channelURL: String)
    case conversations
    case submitCSAT(channelURL: String)
    case handoff(channelURL: String)
    case aiAgentMessageTemplates
    case aiAgentMyGroupChannels(userId: String)
    case aiAgentMyGroupChannelsChangelogs(userId: String)
    case aiAgentUnreadMessageCount(userId: String)
    case closeConversation(channelURL: String)
    case aiAgentMessagesFeedback(channelURL: String, messageId: Int64)
    
    /// SDK API endpoints
    case sdkGroupChannels(_ channelURL: String? = nil)
    case sdkOpenChannels(_ channelURL: String? = nil)
    case sdkUiKitConfiguration
    case sdkUsersPushApns(userId: String)
    case sdkPushDelivery
    case sdkStatistics
    case notificationStatistics
    case settings
    case authenticate(userId: String)
    
    public var splitPath: [CustomStringConvertible] {
        switch self {
            /// Secret", "Application Settings
        case .secretApplicationAttrsReactions(let applicationId):
            return ["secret", applicationId, "attrs", "reactions"]
        case .secretApplicationAttrs(let applicationId), .secretApplicationPlan(let applicationId):
            return ["secret", applicationId, "attrs"]
        case .secretApplicationUiKitConfiguration(let applicationId):
            return ["secret", applicationId, "ui_kit", "configuration"]
        case .secretApplicationNotificationChannels(let applicationId):
            return ["secret", applicationId, "notification_channels"]
        case .applicationsSettingsGlobal:
            return ["applications", "settings_global"]
            /// User Related
        case .users(let userId):
            if let userId {
                return ["users", userId]
            } else {
                return ["users"]
            }
        case .usersLogin(let userId):
            return ["users", userId]
        case .usersToken(let userId):
            return ["users", userId, "token"]
        case .usersSessionKey(let userId):
            return ["users", userId, "session_key"]
        case .usersPush(let userId):
            return ["users", userId, "push"]
        case .usersPushTemplate(let userId):
            return ["users", userId, "push", "template"]
        case .usersPushApns(let userId, let token):
            if let token {
                return ["users", userId, "push", "apns", token]
            } else {
                return ["users", userId, "push"]
            }
        case .usersPushDeviceTokens(let userId, let pushTokenType):
            return ["users", userId, "push", pushTokenType, "device_tokens"]
        case .usersUnreadMessageCount(let userId):
            return ["users", userId, "unread_message_count"]
        case .usersUnreadNotificationCount(let userId):
            return ["notifications", "users", userId, "unread_message_count"]
        case .usersUnreadItemCount(let userId):
            return ["users", userId, "unread_item_count"]
        case .usersUnreadChannelCount(let userId):
            return ["users", userId, "unread_channel_count"]
  
        case .usersCountPreference(let userId, let channelURL):
            return ["users", userId, "count_preference", channelURL]
        case .usersMarkAsReadAll(let userId):
            return ["users", userId, "mark_as_read_all"]
  
        case .usersFriends(let userId):
            return ["users", userId, "friends"]
        case .usersFriendDiscoveries(let userId):
            return ["users", userId, "friend_discoveries"]
        case .usersFriendChangelogs(let userId):
            return ["users", userId, "friends", "changelogs"]
        case .usersAllowFriendDiscovery(let userId):
            return ["users", userId, "allow_friend_discovery"]
        case .usersChannelInvitationPreference(let userId):
            return ["users", userId, "channel_invitation_preference"]
            
        case .usersMetadata(let userId, let key):
            if let key = key {
                return ["users", userId, "metadata", key]
            } else {
                return ["users", userId, "metadata"]
            }
            
        case .usersPushPreference(let userId, let channelURL):
            if let channelURL = channelURL {
                return ["users", userId, "push_preference", channelURL]
            } else {
                return ["users", userId, "push_preference"]
            }
        case .usersMyGroupChannels(let userId):
            return ["users", userId, "my_group_channels"]
        case .usersMyGroupChannelsChangelogs(let userId):
            return ["users", userId, "my_group_channels", "changelogs"]
        case .usersMyGroupChannelsMembersChangelogs(let userId):
            return ["users", userId, "my_group_channels", "members", "changelogs"]
        case .usersBlock(let blockerUserId, let targetUserId):
            if let targetUserId = targetUserId {
                return ["users", blockerUserId, "block", targetUserId]
            } else {
                return ["users", blockerUserId, "block"]
            }
        case .usersGroupChannelCount(let userId):
            return ["users", userId, "group_channel_count"]
            
            /// Group Channels
        case .groupChannels(let channelURL):
            if let channelURL {
                return ["group_channels", channelURL]
            } else {
                return ["group_channels"]
            }
        case .groupChannelsTyping(let channelURL):
            return ["group_channels", channelURL, "typing"]
        case .groupChannelsMessagesMarkAsDelivered(let channelURL):
            return ["group_channels", channelURL, "messages", "mark_as_delivered"]
        case .groupChannelsMessagesMarkAsRead(let channelURL):
            return ["group_channels", channelURL, "messages", "mark_as_read"]
        case .groupChannelsMessagesInReviewTransitions(let channelURL, let messageId):
            return ["group_channels", channelURL, "messages_in_review", messageId, "transitions"]
        case .groupChannelsDistinctMessage:
            return ["group_channels", "distinct_message"]
        case .groupChannelsMembers(let channelURL):
            return ["group_channels", channelURL, "members"]
        case .groupChannelsHide(let channelURL):
            return ["group_channels", channelURL, "hide"]
        case .groupChannelsInvite(let channelURL):
            return ["group_channels", channelURL, "invite"]
        case .groupChannelsAccept(let channelURL):
            return ["group_channels", channelURL, "accept"]
        case .groupChannelsDecline(let channelURL):
            return ["group_channels", channelURL, "decline"]
        case .groupChannelsJoin(let channelURL):
            return ["group_channels", channelURL, "join"]
        case .groupChannelsLeave(let channelURL):
            return ["group_channels", channelURL, "leave"]
        case .groupChannelsResetUserHistory(let channelURL):
            return ["group_channels", channelURL, "reset_user_history"]
        case .groupChannelsScreenshot(let channelURL):
            return ["group_channels", channelURL, "screenshot"]
        case .groupChannelsMessagesFeedbacks(let channelURL, let messageId, let feedbackId):
            if let feedbackId = feedbackId {
                return ["group_channels", channelURL, "messages", messageId, "feedbacks", "\(feedbackId)"]
            } else {
                return ["group_channels", channelURL, "messages", messageId, "feedbacks"]
            }
            
        case .channelMessages(let channelType, let channelURL, let messageId):
            if let messageId {
                return [channelType.urlString, channelURL, "messages", messageId]
            } else {
                return [channelType.urlString, channelURL, "messages"]
            }
            
        case .channelMessagesChangelogs(let channelType, let channelURL):
            return [channelType.urlString, channelURL, "messages", "changelogs"]
        case .channelScheduledMessages(let channelType, let channelURL, let scheduledMessageId):
            if let scheduledMessageId {
                return [channelType.urlString, channelURL, "scheduled_messages", "\(scheduledMessageId)"]
            } else {
                return [channelType.urlString, channelURL, "scheduled_messages"]
            }
        case .channelScheduledMessagesSendNow(let channelType, let channelURL, let scheduledMessageId):
            return [channelType.urlString, channelURL, "scheduled_messages", "\(scheduledMessageId)", "send_now"]
            
        case .channelMessagesPin(let channelType, let channelURL, let messageId):
            return [channelType.urlString, channelURL, "messages", messageId, "pin"]
        case .channelMetacounter(let channelType, let channelURL, let key):
            if let key {
                return [channelType.urlString, channelURL, "metacounter", "\(key.urlEncoded)"]
            } else {
                return [channelType.urlString, channelURL, "metacounter"]
            }
            
        case .scheduledMessagesCount:
            return ["scheduled_messages", "count"]
            
        case .channelOperators(let channelType, let channelURL):
            return [channelType.urlString, channelURL, "operators"]
            
        case .channelMessagesSortedMetaArray(let channelType, let channelURL, let messageId):
            return [channelType.urlString, channelURL, "messages", messageId, "sorted_metaarray"]
            
        case .channelMetadata(let channelType, let channelURL, let key):
            if let key {
                return [channelType.urlString, channelURL, "metadata", "\(key.urlEncoded)"]
            } else {
                return [channelType.urlString, channelURL, "metadata"]
            }
            
        case .channelBan(let channelType, let channelURL, let userId):
            if let userId {
                return [channelType.urlString, channelURL, "ban", userId]
            } else {
                return [channelType.urlString, channelURL, "ban"]
            }
        case .channelFreeze(let channelType, let channelURL):
            return [channelType.urlString, channelURL, "freeze"]
        case .channelMute(let channelType, let channelURL, let userId):
            if let userId {
                return [channelType.urlString, channelURL, "mute", userId]
            } else {
                return [channelType.urlString, channelURL, "mute"]
            }
        case .channelMessagesReactions(let channelType, let channelURL, let messageId):
            return [channelType.urlString, channelURL, "messages", messageId, "reactions"]
        case .channelMessagesTranslation(let channelType, let channelURL, let messageId):
            return [channelType.urlString, channelURL, "messages", messageId, "translation"]
        case .channelPinnedMessages(let channelType, let channelURL):
            return [channelType.urlString, channelURL, "pinned_messages"]
        case .channelMessagePurgeOffset(let channelURL):
            return [AuthChannelType.group.urlString, channelURL, "message_purge_offset"]
            /// Notifications and Templates
        case .notificationsChannels(let channelKey):
            return ["notifications", "channels", channelKey]
        case .notificationsChannelsCategories(let channelKey, let categoryId):
            return ["notifications", "channels", "\(channelKey.urlEncoded)", "categories", "\(categoryId.urlEncoded)"]
        case .notificationsSettings:
            return ["notifications", "settings"]
        case .notificationsTemplates(let key):
            if let key {
                return ["notifications", "templates", "\(key.urlEncoded)"]
            } else {
                return ["notifications", "templates"]
            }
            
            /// Bots
        case .bots(let botId):
            return ["bots", "\(botId.urlEncoded)"]
        case .botsSend(let botUserId):
            return ["bots", "\(botUserId.urlEncoded)", "send"]
            
            /// Custom Responses
        case .customResponses:
            return ["custom_responses"]
            
            /// Polls
        case .polls(let pollId):
            if let pollId {
                return ["polls", "\(pollId)"]
            } else {
                return ["polls"]
            }
        case .pollsVote(let pollId):
            return ["polls", "\(pollId)", "vote"]
        case .pollsClose(let pollId):
            return ["polls", "\(pollId)", "close"]
        case .pollsOptions(let pollId, let pollOptionId):
            if let pollOptionId = pollOptionId {
                return ["polls", "\(pollId)", "options", "\(pollOptionId)"]
            } else {
                return ["polls", "\(pollId)", "options"]
            }
        case .pollsOptionsVoters(let pollId, let pollOptionId):
            return ["polls", "\(pollId)", "options", "\(pollOptionId)", "voters"]
        case .pollsChangelogs(let channelType, let channelURL):
            return [channelType.urlString, channelURL, "polls", "changelogs"]
            
            /// Reporting
        case .reportUsers(let reportedUserId):
            return ["report", "users", reportedUserId]
        case .reportChannel(let channelType, let channelURL):
            return ["report", channelType.urlString, channelURL]
        case .reportChannelMessage(let channelType, let channelURL, let messageId):
            return ["report", channelType.urlString, channelURL, "messages", messageId]
        case .reportCategory:
            return ["report_category"]

            /// Open Channels
        case .openChannels(let channelURL):
            if let channelURL {
                return ["open_channels", channelURL]
            } else {
                return ["open_channels"]
            }
            
        case .openChannelsParticipants(let channelURL):
            return ["open_channels", channelURL, "participants"]
            
            /// Emojis and Categories
        case .emojis(let emojiKey):
            return ["emojis", "\(emojiKey.urlEncoded)"]
        case .emojiCategories(let categoryId):
            if let categoryId {
                return ["emoji_categories", "\(categoryId)"]
            } else {
                return ["emoji_categories"]
            }
            
            /// Forms
        case .formsSubmit(let formId):
            return ["forms", formId, "submit"]
        case .forms:
            return ["forms"]
        case .formsId(let formId):
            return ["forms", formId]
            
            /// workflow for tests
        case .workflows(let workflowId):
            if let workflowId {
                return ["workflows", workflowId]
            } else {
                return ["workflows"]
            }
            
            /// AuthAIAgent messagenser settings
        case .messengerSettings(let aiAgentId):
            return ["ai_agent", "ai_agents", aiAgentId.urlEncoded, "messenger_settings"]
            
            /// AIAgent Get/Update context object
        case .aiAgentContext(let aiAgentId, let channelURL):
            return ["ai_agent", "ai_agents", aiAgentId.urlEncoded, "channels", channelURL.urlEncoded, "ai_agent_context"]
            
        case .conversations:
            return ["ai_agent", "my_conversations"]
            
        case .submitCSAT(let channelURL):
            return ["ai_agent", "group_channels", channelURL, "submit_csat"]
            
        case .handoff(let channelURL):
            return ["ai_agent", "group_channels", channelURL, "handoff"]
            
        case .aiAgentMessageTemplates:
            return ["ai_agent", "sdk_message_templates"]
            
        case .aiAgentMyGroupChannels(let userId):
            return ["ai_agent", "users", userId, "my_group_channels"]
            
        case .aiAgentMyGroupChannelsChangelogs(let userId):
            return ["ai_agent", "users", userId, "my_group_channels", "changelogs"]
        
        case .aiAgentUnreadMessageCount(let userId):
            return ["ai_agent", "users", userId, "my_group_channels", "unread_message_count"]
            
        case .closeConversation(let channelURL):
            return ["ai_agent", "group_channels", channelURL, "close_conversation"]
            
        case .aiAgentMessagesFeedback(let channelURL, let messageId):
            return ["ai_agent", "group_channels", channelURL, "messages", messageId, "feedback"]
            
            /// SDK API Endpoints
        case .sdkGroupChannels(let channelURL):
            if let channelURL {
                return ["sdk", "group_channels", channelURL]
            } else {
                return ["sdk", "group_channels"]
            }
        case .sdkOpenChannels(let channelURL):
            if let channelURL {
                return ["sdk", "open_channels", channelURL]
            } else {
                return ["sdk", "open_channels"]}
        case .sdkUiKitConfiguration:
            return ["sdk", "ui_kit", "configuration"]
        case .sdkUsersPushApns(let userId):
            return ["sdk", "users", userId, "push", "apns"]
        case .sdkPushDelivery:
            return ["sdk", "push_delivery"]
        case .searchMessages:
            return ["search", "messages"]
        case .storageFile:
            return ["storage", "file"]
        case .sdkStatistics:
            return ["sdk", "statistics"]
        case .notificationStatistics:
            return ["sdk", "notification_statistics"]
        case .settings:
            return ["sdk", "applications", "settings"]
        case .authenticate(let userId):
            return ["sdk", "users", userId, "authentication"]
        }
    }
}
