import Foundation

public enum TeamsOverlayState: Equatable, Sendable {
    case apiUnavailable(String)
    case disconnected
    case pairingRequired
    case notInMeeting
    case muted
    case unmuted
    case syncing(previous: MuteValue)
    case error(String)
}

public enum MuteValue: String, Equatable, Sendable {
    case muted
    case unmuted
}

public extension TeamsOverlayState {
    var canToggleMute: Bool {
        self == .muted || self == .unmuted
    }

    var shortLabel: String {
        switch self {
        case .apiUnavailable:
            return "API OFF"
        case .disconnected:
            return "OFFLINE"
        case .pairingRequired:
            return "PAIR"
        case .notInMeeting:
            return "IDLE"
        case .muted:
            return "MUTED"
        case .unmuted:
            return "LIVE"
        case .syncing:
            return "SYNC"
        case .error:
            return "ERROR"
        }
    }

    var detail: String {
        switch self {
        case .apiUnavailable(let reason):
            return reason
        case .disconnected:
            return "Teams API disconnected"
        case .pairingRequired:
            return "Join a meeting and allow pairing in Teams"
        case .notInMeeting:
            return "Teams is running, no active meeting"
        case .muted:
            return "Teams microphone is muted"
        case .unmuted:
            return "Teams microphone is live"
        case .syncing:
            return "Waiting for Teams confirmation"
        case .error(let message):
            return message
        }
    }
}

public struct OverlayStateReducer: Sendable {
    public init() {}

    public func reduce(update: MeetingUpdate, hasStoredToken: Bool) -> TeamsOverlayState {
        if update.meetingPermissions?.canPair == true {
            return .pairingRequired
        }

        guard let meetingState = update.meetingState else {
            return .disconnected
        }

        guard meetingState.isInMeeting else {
            return .notInMeeting
        }

        return meetingState.isMuted ? .muted : .unmuted
    }

    public func syncingState(from state: TeamsOverlayState) -> TeamsOverlayState? {
        switch state {
        case .muted:
            return .syncing(previous: .muted)
        case .unmuted:
            return .syncing(previous: .unmuted)
        default:
            return nil
        }
    }

    public func didConfirmToggle(previous: MuteValue, update: MeetingUpdate) -> Bool {
        guard let state = update.meetingState, state.isInMeeting else {
            return false
        }

        switch previous {
        case .muted:
            return state.isMuted == false
        case .unmuted:
            return state.isMuted == true
        }
    }
}
