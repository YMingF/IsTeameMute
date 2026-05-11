import Foundation

public struct TeamsMessage: Codable, Equatable, Sendable {
    public var meetingUpdate: MeetingUpdate?
    public var requestId: Int?
    public var response: String?
    public var tokenRefresh: String?

    public init(
        meetingUpdate: MeetingUpdate? = nil,
        requestId: Int? = nil,
        response: String? = nil,
        tokenRefresh: String? = nil
    ) {
        self.meetingUpdate = meetingUpdate
        self.requestId = requestId
        self.response = response
        self.tokenRefresh = tokenRefresh
    }
}

public struct MeetingUpdate: Codable, Equatable, Sendable {
    public var meetingState: MeetingState?
    public var meetingPermissions: MeetingPermissions?

    public init(meetingState: MeetingState? = nil, meetingPermissions: MeetingPermissions? = nil) {
        self.meetingState = meetingState
        self.meetingPermissions = meetingPermissions
    }
}

public struct MeetingState: Codable, Equatable, Sendable {
    public var isMuted: Bool
    public var isVideoOn: Bool
    public var isHandRaised: Bool
    public var isInMeeting: Bool
    public var isRecordingOn: Bool
    public var isBackgroundBlurred: Bool
    public var isSharing: Bool
    public var hasUnreadMessages: Bool

    public init(
        isMuted: Bool = false,
        isVideoOn: Bool = false,
        isHandRaised: Bool = false,
        isInMeeting: Bool = false,
        isRecordingOn: Bool = false,
        isBackgroundBlurred: Bool = false,
        isSharing: Bool = false,
        hasUnreadMessages: Bool = false
    ) {
        self.isMuted = isMuted
        self.isVideoOn = isVideoOn
        self.isHandRaised = isHandRaised
        self.isInMeeting = isInMeeting
        self.isRecordingOn = isRecordingOn
        self.isBackgroundBlurred = isBackgroundBlurred
        self.isSharing = isSharing
        self.hasUnreadMessages = hasUnreadMessages
    }
}

public struct MeetingPermissions: Codable, Equatable, Sendable {
    public var canToggleMute: Bool
    public var canToggleVideo: Bool
    public var canToggleHand: Bool
    public var canToggleBlur: Bool
    public var canLeave: Bool
    public var canReact: Bool
    public var canToggleShareTray: Bool
    public var canToggleChat: Bool
    public var canStopSharing: Bool
    public var canPair: Bool

    public init(
        canToggleMute: Bool = false,
        canToggleVideo: Bool = false,
        canToggleHand: Bool = false,
        canToggleBlur: Bool = false,
        canLeave: Bool = false,
        canReact: Bool = false,
        canToggleShareTray: Bool = false,
        canToggleChat: Bool = false,
        canStopSharing: Bool = false,
        canPair: Bool = false
    ) {
        self.canToggleMute = canToggleMute
        self.canToggleVideo = canToggleVideo
        self.canToggleHand = canToggleHand
        self.canToggleBlur = canToggleBlur
        self.canLeave = canLeave
        self.canReact = canReact
        self.canToggleShareTray = canToggleShareTray
        self.canToggleChat = canToggleChat
        self.canStopSharing = canStopSharing
        self.canPair = canPair
    }
}

public struct ServiceRequest: Codable, Equatable, Sendable {
    public var action: String
    public var parameters: [String: String]
    public var requestId: Int

    public init(action: String, requestId: Int, parameters: [String: String] = [:]) {
        self.action = action
        self.parameters = parameters
        self.requestId = requestId
    }
}

public struct ServiceResponse: Codable, Equatable, Sendable {
    public var requestId: Int
    public var response: String

    public init(requestId: Int, response: String) {
        self.requestId = requestId
        self.response = response
    }
}
