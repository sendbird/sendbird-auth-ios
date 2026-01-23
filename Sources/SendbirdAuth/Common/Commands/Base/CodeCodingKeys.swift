//
//  CodingKeys.swift
//  SendbirdChatSDK
//
//  Created by Minhyuk Kim on 2024/02/16.
//
import Foundation

// swiftlint:disable identifier_name
@_spi(SendbirdInternal) public enum CodeCodingKeys: String, CodingKey, Codable, CustomStringConvertible {
    @_spi(SendbirdInternal) public var description: String { rawValue }
    
    case accessCode = "access_code"
    case accentColor = "accent_color"
    case isAccessCodeRequired = "is_access_code_required"
    case action
    case activeChannel = "active_channel"
    case advancedQuery = "advanced_query"
    case after
    case aiMeta = "ai_meta"
    case aiAgent = "ai_agent"
    case aiAgentId = "ai_agent_id"
    case aiAgentIds = "ai_agent_ids"
    case aiAgentChannel = "ai_agent_channel"
    case aiAgentChannelFilter = "ai_agent_channel_filter"
    case aiAgentConversationStatusFilter = "ai_agent_conversation_status_filter"
    case all
    case allowAutoUnhide = "allow_auto_unhide"
    case allowFriendDiscovery = "allow_friend_discovery"
    case allowMultipleVotes = "allow_multiple_votes"
    case allowSDKFeatureLocalCacheLogPublish = "allow_sdk_feature_local_cache_log_publish"
    case allowSDKNotiStatsLogPublish = "allow_sdk_noti_stats_log_publish"
    case allowSDKRequestLogPublish = "allow_sdk_request_log_publish"
    case allowUserSuggestion = "allow_user_suggestion"
    case allowOther = "allow_other"
    case alt
    case android
    case api
    case apns
    case apnsDeviceToken = "apns_device_token"
    case appearance
    case appleCriticalAlertOptions = "apple_critical_alert_options"
    case applicationAttributes = "application_attributes"
    case appId = "app_id"
    case autoAccept = "auto_accept"
    case autoOpen = "auto_open"
    case backOffDelay = "back_off_delay"
    case backSync = "back_sync"
    case bad
    case ban
    case banned
    case bannedList = "banned_list"
    case base64File = "base_64_file"
    case before
    case binary
    case bind
    case block
    case blockee
    case blocker
    case bot = "bot"
    case botMessageColor = "bot_message_color"
    case botMessageBgColor = "bot_message_bg_color"
    case botProfileURL = "bot_profile_url"
    case botStyle = "bot_style"
    case botUserId = "bot_userid"
    case cache
    case cacheAndReplaceByApi = "cache_and_replace_by_api"
    case calls
    case canceled
    case cat
    case categories
    case changedChannelMembers = "changed_channel_members"
    case changedMembers = "changed_members"
    case changelogs
    case channel
    case channelCustomType = "channel_custom_type"
    case channelId = "channel_id"
    case channelKey = "channel_key"
    case channelType = "channel_type"
    case channelURL = "channel_url"
    case channelURLs = "channel_urls"
    case channels
    case chat
    case checkingContinuousMessages = "checking_continuous_messages"
    case checkingHasNext = "checking_has_next"
    case messageChunk = "message_chunk"
    case chunkRangeEnd = "chunk_range_end"
    case chunkRangeStart = "chunk_range_start"
    case close
    case closeAt = "close_at"
    case closed
    case code
    case collection
    case collectionId = "collection_id"
    case collectionInterface = "collection_interface"
    case column
    case color
    case context
    case command
    case comment
    case common
    case concurrentCallLimit = "concurrent_call_limit"
    case configSyncNeeded = "config_sync_needed"
    case connected
    case containerOptions = "container_options"
    case countPreference = "count_preference"
    case coverURL = "cover_url"
    case conversation
    case conversations
    case created
    case createdAfter = "created_after"
    case createdAt = "created_at"
    case createdBefore = "created_before"
    case createdBy = "created_by"
    case createUserAndChannel = "create_user_and_channel"
    case createChannel = "create_channel"
    case custom
    case customType = "custom_type"
    case customTypeStartsWith = "custom_type_startswith"
    case customTypes = "custom_types"
    case dark
    case data
    case debug
    case decimalPlace = "decimal_place"
    case delete
    case deleteAll = "delete_all"
    case deleted
    case deletedAt = "deleted_at"
    case deliveryReceipt = "delivery_receipt"
    case description
    case definition
    case reportDescription = "report_description"
    case desk
    case deskChannel = "desk_channel"
    case deskChannelFilter = "desk_channel_filter"
    case detail
    case determinedBy = "determined_by"
    case deviceId = "device_id"
    case deviceManufacturer = "device_manufacturer"
    case deviceOS = "device_os"
    case deviceToken = "device_token"
    case deviceTokenLastDeletedAt = "device_token_last_deleted_at"
    case deviceTokens = "device_tokens"
    case defaultOptions = "default_options"
    case didSetMentionType = "did_set_mention_type"
    case didSetMentionedUsers = "did_set_mentioned_users"
    case didSetParentMessageId = "did_set_parent_message_id"
    case disableSuperGroupMACK = "disable_supergroup_mack"
    case disabled
    case discoveryKeys = "discovery_keys"
    case distinctMode = "distinct_mode"
    case double
    case ekey
    case email
    case emojiCategories = "emoji_categories"
    case emojiHash = "emoji_hash"
    case emojis
    case doNotDisturb = "do_not_disturb"
    case `enum`
    case enable
    case enabled
    case endAt = "end_at"
    case endHour = "end_hour"
    case endMin = "end_min"
    case snoozeEndTs = "snooze_end_ts"
    case endTs = "end_ts"
    case endCursor = "end_cursor"
    case endpoint
    case error
    case errorCode = "error_code"
    case errorDescription = "error_description"
    case event
    case eventType = "event_type"
    case exactMatch = "exact_match"
    case expireAt = "expire_at"
    case expiresAt = "expires_at"
    case expiresIn = "expires_in"
    case expiringSession = "expiring_session"
    case expression
    case extendedMessage = "extended_message"
    case extendedMessagePayload = "extended_message_payload"
    case external
    case failed
    case failure
    case feed
    case feedChannels = "feed_channels"
    case feedback
    case feedbacks
    case cacheFetch = "cache_fetch"
    case country
    case csat
    case csatType = "csat_type"
    case csatReason = "csat_reason"
    case csatExpireAt = "csat_expire_at"
    case fields
    case file
    case fileName = "file_name"
    case fileSize = "file_size"
    case fileType = "file_type"
    case files
    case isMultipleFilesMessage  // for local pending, failed MFM
    case forceUpdateLastMessage = "force_update_last_message"
    case formKey = "form_key"
    case messageForm = "message_form"
    case forms
    case formData = "form_data"
    case formItemId = "form_item_id"
    case found
    case freeze
    case friendDiscoveries = "friend_discoveries"
    case friendDiscoveryKey = "friend_discovery_key"
    case friendDiscoveryKeys = "friend_discovery_keys"
    case friendName = "friend_name"
    case friends
    case gapCheck = "gap_check"
    case good
    case groupChannelCount = "group_channel_count"
    case groupChannelInvitationCount = "group_channel_invitation_count"
    case groupChannelUnreadMentionCount = "group_channel_unread_mention_count"
    case groupChannelUnreadMessageCount = "group_channel_unread_message_count"
    case groupChannel = "group_channel"
    case groupChannels = "group_channels"
    case guestId = "guest_id"
    case handler = "handler"
    case handoff = "handoff"
    case handedOverAt = "handed_over_at"
    case hasLastMessage = "has_last_message"
    case hasMore = "has_more"
    case hasNext = "has_next"
    case hasAIBot = "has_ai_bot"
    case hasBot = "has_bot"
    case rowId = "row_id"
    case height = "height"
    case helpdeskInfo = "helpdesk_info"
    case hiddenMode = "hidden_mode"
    case hiddenState = "hidden_state"
    case hide
    case hidePreviousMessages = "hide_previous_messages"
    case cacheHit = "cache_hit"
    case hostURL = "host_url"
    case id
    case image
    case imageType = "image_type"
    case imageURL = "image_url"
    case interval
    case inQueue = "in_queue"
    case includeChatNotification = "include_chat_notification"
    case includeEmptyChannel = "include_empty_channel"
    case includeExtraData = "include_extra_data"
    case includeFeedChannel = "include_feed_channel"
    case includeFrozenChannel = "include_frozen_channel"
    case includeLeftChannel = "include_left_channel"
    case includeLOGI = "include_logi"
    case includeNotJoinedPublic = "include_not_joined_public"
    case includeNotJoinedPublicChannel = "include_not_joined_public_channel"
    case includeOpen = "include_open"
    case includeOpenChannel = "include_open_channel"
    case includeParentMessageInfo = "include_parent_message_info"
    case includePollDetails = "include_poll_details"
    case includeReactions = "include_reactions"
    case includeReactionsSummary = "include_reactions_summary"
    case includeReplyType = "include_reply_type"
    case includeThreadInfo = "include_thread_info"
    case includeTs = "include_ts"
    case include = "include"
    case info
    case initialLoad = "initial_load"
    case inputType = "input_type"
    case integer
    case internalFileName = "internal_file_name"
    case internalFileURL = "internal_file_url"
    case internalMimeType = "internal_mime_type"
    case invalid
    case invitationStatus = "invitation_status"
    case invitedAt = "invited_at"
    case invitee
    case invitees
    case inviter
    case inviterId = "inviter_id"
    case invoked
    case ios
    case isActive = "is_active"
    case isAIAgentChannel = "is_ai_agent_channel"
    case isBlockedByMe = "is_blocked_by_me"
    case isBlockingMe = "is_blocking_me"
    case isBot = "is_bot"
    case isBroadcast = "is_broadcast"
    case isCategoryFilterEnabled = "is_category_filter_enabled"
    case isChatNotification = "is_chat_notification"
    case isContinuousMessages = "is_continuous_messages"
    case isContinuousNextMessages = "is_continuous_next_messages"
    case isContinuousPrevMessages = "is_continuous_prev_messages"
    case isConversation = "is_conversation"
    case isConversationClosed = "is_conversation_closed"
    case isCreated = "is_created"
    case isDefault = "is_default"
    case isDeskChannel = "is_desk_channel"
    case isDiscoverable = "is_discoverable"
    case isDistinct = "is_distinct"
    case isEphemeral = "is_ephemeral"
    case isExclusive = "is_exclusive"
    case isExplicitRequest = "is_explicit_request"
    case isFeedChannel = "is_feed_channel"
    case isResolved = "is_resolved"
    case showPinnedMessages = "show_pinned_messages"
    case isFrozen = "is_frozen"
    case isHidden = "is_hidden"
    case isHugeGap = "is_huge_gap"
    case isMuted = "is_muted"
    case isOnline = "is_online"
    case isOperatorMessage = "is_op_msg"
    case pinMessage = "pin_message"
    case pinnedChannelURLs = "pinned_channel_urls"
    case isPublic = "is_public"
    case isReplyToChannel = "is_reply_to_channel"
    case isSDK = "is_sdk"
    case isSilent = "is_silent"
    case allowSDKLogIngestion = "allow_sdk_log_ingestion"
    case ai
    case isSuper = "is_super"
    case isSubmitted = "is_submitted"
    case isTemplateLabelEnabled = "is_template_label_enabled"
    case isUnique = "is_unique"
    case isUploaded
    case items
    case itemType = "item_type"
    case itemKeys = "item_keys"
    case joinedTs = "joined_ts"
    case joinedMemberCount = "joined_member_count"
    case reaction
    case key
    case keys
    case keyword
    case knownActiveChannelURL = "known_active_channel_url"
    case label
    case layout
    case language
    case lastMessage = "last_message"
    case lastMessageTs = "last_message_ts"
    case latestPinnedMessage = "latest_pinned_message"
    case userLastRead = "user_last_read"
    case lastRepliedAt = "last_replied_at"
    case lastSeenAt = "last_seen_at"
    case lastSyncedChangeLogsTs = "last_synced_changelog_ts"
    case lastTs = "last_ts"
    case lastUpdatedAt = "last_updated_at"
    case latency
    case latestMessage = "latest_message"
    case launcher
    case leave
    case light
    case limit
    case live
    case loadNext = "load_next"
    case loadPrev = "load_prev"
    case locale
    case logEntries = "log_entries"
    case logPublishConfig = "log_publish_config"
    case loginTimestamp = "login_ts"
    case low
    case manual
    case markAsRead = "mark_as_read"
    case maxDBSize = "max_db_size"
    case maxSize
    case maxUnreadCountOnSuperGroup = "max_unread_cnt_on_super_group"
    case maxInterval = "max_interval"
    case retryCount = "retry_cnt"
    case measuredOn = "measured_on"
    case member
    case memberCount = "member_count"
    case membersNicknameContains = "members_nickname_contains"
    case membersNickname = "members_nickname"
    case membersNicknameStartsWith = "members_nickname_startswith"
    case memberState = "member_state"
    case memberStateFilter = "member_state_filter"
    case members
    case membersExactlyIn = "members_exactly_in"
    case membersIncludeIn = "members_include_in"
    case mentionType = "mention_type"
    case mentionedMessageTemplate = "mentioned_message_template"
    case mentionedUserIds = "mentioned_user_ids"
    case mentionedUsers = "mentioned_users"
    case message
    case messageCollectionInitPolicy = "message_init_policy"
    case messageCollectionLastAccessedAt = "message_collection_last_accessed_at"
    case messageCreatedAt = "message_created_at"
    case messageEvents = "message_events"
    case messageId = "message_id"
    case messageIds = "message_ids"
    case tsMessageOffset = "ts_message_offset"
    case messagePurgeOffset = "message_purge_offset"
    case messageParams = "message_params"
    case reviewInfo = "review_info"
    case messageStatus = "message_status"
    case messageSurvivalSeconds = "message_survival_seconds"
    case messageTemplate = "message_template"
    case messageToken = "mesg_token"
    case messageTsFrom = "message_ts_from"
    case messageTimestampFrom = "message_timestamp_from"
    case messageTsTo = "message_ts_to"
    case messageTimestampTo = "message_timestamp_to"
    case messageTs = "message_ts"
    case messageType = "message_type"
    case resolution
    case results
    case resultCount = "result_count"
    case messages
    case messagesAfterSubmission = "messages_after_submission"
    case metaArray = "metaarray"
    case metaArrayKeyOrder = "metaarray_key_order"
    case metacounter
    case metadata
    case metadata_key = "metadata_key"
    case metadataKey = "metadatakey"
    case metadataOrderKey = "metadata_order_key"
    case metadataValueStartswith = "metadata_value_startswith"
    case metadataValuesIn = "metadatavalues_in"
    case metadataValues = "metadata_values"
    case method
    case min
    case minLength = "min_length"
    case max
    case maxLength = "max_length"
    case maxDecimalPlace = "max_decimal_place"
    case cacheMiss = "cache_miss"
    case mode
    case mostReplies = "most_replies"
    case msgId = "msg_id"
    case multipleFileSendMaxSize = "multiple_file_send_max_size"
    case multiplier = "mul"
    case mute
    case muted
    case mutedDescription = "muted_description"
    case mutedEndAt = "muted_end_at"
    case mutedMemberFilter = "muted_member_filter"
    case mutedStartAt = "muted_start_at"
    case myRole = "my_role"
    case name
    case criticalSound = "critical_sound"
    case nameContains = "name_contains"
    case newKey = "new_key"
    case next
    case nextToken = "next_token"
    case nextCacheCount = "next_cache_count"
    case nextEndTs = "next_end_ts"
    case nextHasMore = "next_hasmore"
    case nextLimit = "next_limit"
    case nextMessages = "next_messages"
    case nextStartTs = "next_start_ts"
    case nickname
    case nicknameStartsWith = "nickname_startswith"
    case nonSuperInvitationCount = "non_super_group_channel_invitation_count"
    case nonSuperUnreadMentionCount = "non_super_group_channel_unread_mention_count"
    case nonSuperUnreadMessageCount = "non_super_group_channel_unread_message_count"
    case none
    case notificationMessageStatus = "notification_message_status"
    case notifications
    case notificationEventDeadline = "notification_event_deadline"
    case number
    case offendingUserId = "offending_user_id"
    case ogTag = "og_tag"
    case oldValues = "old_values"
    case open
    case openChannels = "open_channels"
    case operation
    case operatorFilter = "operator_filter"
    case operatorIds = "operator_ids"
    case operators
    case options
    case order
    case originalMessageInfo = "original_message_info"
    case parentMessageInfo = "parent_message_info"
    case parentMessageId = "parent_message_id"
    case parentMessageText = "parent_message_text"
    case participantCount = "participant_count"
    case participants
    case password
    case patch
    case payload
    case pending
    case phone
    case pin
    case ping
    case pingInterval = "ping_interval"
    case pinnedMessageIds = "pinned_message_ids"
    case pinnedMessages = "pinned_messages"
    case placeholder
    case plugins
    case poll
    case pollId = "poll_id"
    case optionId = "option_id"
    case pollOptionId = "poll_option_id"
    case polls
    case preferredLanguages = "preferred_languages"
    case premiumFeatureList = "premium_feature_list"
    case prepare
    case prev
    case prevCacheCount = "prev_cache_count"
    case prevEndTs = "prev_end_ts"
    case prevHasMore = "prev_hasmore"
    case prevLimit = "prev_limit"
    case prevMessages = "prev_messages"
    case previousMessageId = "previous_message_id"
    case prevStartTs = "prev_start_ts"
    case prevSyncComplete = "prev_sync_complete"
    case primaryColor = "primary_color"
    case priority
    case process
    case profile
    case profileURL = "profile_url"
    case publicMembershipMode = "public_membership_mode"
    case publicMode = "public_mode"
    case push
    case pushAcknowledgement = "push_acknowledgement"
    case pushOption = "push_option"
    case pushSound = "push_sound"
    case pushTrackingId = "push_tracking_id"
    case pushTriggerOption = "push_trigger_option"
    case query
    case queryType = "query_type"
    case rating
    case reactions
    case reactionsSummary = "reactions_summary"
    case readReceipt = "read_receipt"
    case realHeight = "real_height"
    case realWidth = "real_width"
    case reason
    case reasonCode = "reason_code"
    case receivers
    case reconnect = "reconnect"
    case refreshing
    case regex
    case remainingDuration = "remaining_duration"
    case nextRequestMs = "next_request_ms"
    case replyCount = "reply_count"
    case replyToChannel = "reply_to_channel"
    case replyToFile = "reply_to_file"
    case report
    case reportCategory = "report_category"
    case requestDedupIntervalMs = "request_dedup_interval_ms"
    case customReportCategoryName = "custom_report_category_name"
    case reportingUserId = "reporting_user_id"
    case reqId = "req_id"
    case requestId = "request_id"
    case requestedMentionUserIds = "requested_mention_user_ids"
    case requireAuth = "require_auth"
    case requireAuthForProfileImage = "require_auth_for_profile_image"
    case required
    case resetAll = "reset_all"
    case restrictionType = "restriction_type"
    case reverse
    case retryAfter = "retry_after"
    case role
    case rootMessageId = "root_message_id"
    case runtimeId = "runtime_id"
    case scheduledAt = "scheduled_at"
    case scheduledId = "scheduled_id"
    case scheduledMessageId = "scheduled_message_id"
    case scheduledMessageParams = "scheduled_message_params"
    case scheduledMessages = "scheduled_messages"
    case scheduledStatus = "scheduled_status"
    case sdk
    case sdkSource = "sdk_source"
    case sdkDeviceTokenCache = "sdk_device_token_cache"
    case searchFields = "search_fields"
    case searchQuery = "search_query"
    case seconds
    case secureURL = "secure_url"
    case sendPushNotification = "send_push_notification"
    case sender
    case senderId = "sender_id"
    case senderUserId = "sender_user_id"
    case senderIds = "sender_ids"
    case sendingStatus = "sending_status"
    case sent
    case serializedData = "serialized_data"
    case services
    case session
    case sessionToken = "session_token"
    case sessioney
    case settings
    case settingsUpdatedAt = "settings_updated_at"
    case shouldRemoveOperatorStatus = "should_remove_operator_status"
    case showColorVariables = "show_color_variables"
    case showDeliveryReceipt = "show_delivery_receipt"
    case showEmpty = "show_empty"
    case showFrozen = "show_frozen"
    case showLatestMessage = "show_latest_message"
    case showMember = "show_member"
    case showMemberIsMuted = "show_member_is_muted"
    case showMetadata = "show_metadata"
    case showReadReceipt = "show_read_receipt"
    case showSubchannelMessagesOnly = "show_subchannel_messages_only"
    case showUITemplate = "show_ui_template"
    case showConversation = "show_conversation"
    case silent
    case size
    case snoozeEnabled = "snooze_enabled"
    case socket
    case sortField = "sort_field"
    case sortedMetaArray = "sorted_metaarray"
    case sortOrder = "sort_order"
    case source
    case startAt = "start_at"
    case startHour = "start_hour"
    case startMin = "start_min"
    case startTs = "start_ts"
    case snoozeStartTimestamp = "snooze_start_ts"
    case startingPoint = "starting_point"
    case statId = "stat_id"
    case statType = "stat_type"
    case state
    case status
    case step
    case strict
    case string
    case style
    case submitForms
    case submitted
    case success
    case suggestedReplies = "suggested_replies"
    case superMode = "super_mode"
    case superInvitationCount = "super_group_channel_invitation_count"
    case superUnreadMentionCount = "super_group_channel_unread_mention_count"
    case superUnreadMessageCount = "super_group_channel_unread_message_count"
    case systemPushEnabled = "system_push_enabled"
    case tag
    case tags
    case target
    case targetFields = "target_fields"
    case translationTargetLangs = "translation_target_langs"
    case targetLangs = "target_langs"
    case targetId = "target_id"
    case templateKey = "template_key"
    case templateListToken = "template_list_token"
    case templateVariables = "template_variables"
    case templates
    case text
    case threadInfo = "thread_info"
    case thumbnailSizes = "thumbnail_sizes"
    case thumbnails
    case theme
    case time
    case ts
    case changeTs = "change_ts"
    case timestamp
    case scheduledTimezone = "scheduled_timezone"
    case timezone
    case title
    case ticketId = "ticket_id"
    case ticketStatus = "ticket_status"
    case token
    case endToken = "end_token"
    case topic
    case topics
    case total
    case totalCount = "total_count"
    case translations
    case type
    case uikitConfig = "uikit_config"
    case unavailable
    case unban
    case unknown
    case unreadCnt = "unread_cnt"
    case unreadCount = "unread_count"
    case unreadFeedCount = "unread_feed_count"
    case unreadFilter = "unread_filter"
    case unreadMentionCount = "unread_mention_count"
    case unreadMessageCount = "unread_message_count"
    case update
    case updateLastMessage = "update_last_message"
    case updateMentionCount = "update_mention_count"
    case updateUnreadCount = "update_unread_count"
    case updated
    case updatedAt = "updated_at"
    case localUpdatedAt = "local_updated_at"
    case latestUpdatedAt = "latest_updated_at"
    case updatedVoteCounts = "updated_vote_counts"
    case fileUploadSizeLimit = "file_upload_size_limit"
    case uploadedBinaryData // Only for DB
    case upsert
    case url
    case urlContains = "url_contains"
    case useLocalCache = "use_local_cache"
    case useNativeWS = "ios_native_ws"
    case useReaction = "use_reaction"
    case user
    case userId = "user_id"
    case userIds = "user_ids"
    case sampledUserIds = "sampled_user_ids"
    case sampledUserInfo = "sampled_user_info"
    case count
    case isSelfIncluded = "is_self_included"
    case users
    case mutedList = "muted_list"
    case value
    case values
    case validators
    case vendor
    case verbose
    case variables
    case version
    case view
    case viewVariables = "view_variables"
    case volume
    case voteCount = "vote_count"
    case votedOptionIds = "voted_option_ids"
    case optionIds = "option_ids"
    case voterCount = "voter_count"
    case voters
    case warning
    case watchdog
    case pongTimeout = "pong_timeout"
    case width = "width"
    case withSortedMetaArray = "with_sorted_meta_array"
    case hardDelete = "hard_delete"
    case isExcluded = "is_excluded"
    case uniqueId = "unique_id"
    case totalUnreadCount = "total_unread_count"
}
// swiftlint:enable identifier_name 
