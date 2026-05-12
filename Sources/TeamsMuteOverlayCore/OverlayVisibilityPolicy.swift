import Foundation

public struct OverlayVisibilityPolicy: Sendable {
    public init() {}

    public func shouldShowOverlay(
        state: TeamsOverlayState,
        isInActiveMeeting: Bool,
        hasSeenActiveMeeting: Bool
    ) -> Bool {
        switch state {
        case .muted, .unmuted:
            return isInActiveMeeting
        case .syncing:
            return isInActiveMeeting && hasSeenActiveMeeting
        case .pairingRequired, .error:
            return hasSeenActiveMeeting
        case .apiUnavailable, .disconnected, .notInMeeting:
            return false
        }
    }
}
