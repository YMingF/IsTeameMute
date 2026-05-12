import XCTest
@testable import TeamsMuteOverlayCore

final class OverlayVisibilityPolicyTests: XCTestCase {
    private let policy = OverlayVisibilityPolicy()

    func testInitialDisconnectedBeforeMeetingUpdateKeepsOverlayHidden() {
        XCTAssertFalse(
            policy.shouldShowOverlay(
                state: .disconnected,
                isInActiveMeeting: false,
                hasSeenActiveMeeting: false
            )
        )
    }

    func testNotInMeetingUpdateHidesOverlay() {
        XCTAssertFalse(
            policy.shouldShowOverlay(
                state: .notInMeeting,
                isInActiveMeeting: false,
                hasSeenActiveMeeting: true
            )
        )
    }

    func testMutedAndUnmutedActiveMeetingUpdatesShowOverlay() {
        XCTAssertTrue(
            policy.shouldShowOverlay(
                state: .muted,
                isInActiveMeeting: true,
                hasSeenActiveMeeting: false
            )
        )
        XCTAssertTrue(
            policy.shouldShowOverlay(
                state: .unmuted,
                isInActiveMeeting: true,
                hasSeenActiveMeeting: false
            )
        )
    }

    func testSyncingRemainsVisibleAfterActiveMeetingWasSeen() {
        XCTAssertTrue(
            policy.shouldShowOverlay(
                state: .syncing(previous: .unmuted),
                isInActiveMeeting: true,
                hasSeenActiveMeeting: true
            )
        )
    }

    func testSyncingHidesWhenLatestMeetingSignalSaysNoActiveMeeting() {
        XCTAssertFalse(
            policy.shouldShowOverlay(
                state: .syncing(previous: .unmuted),
                isInActiveMeeting: false,
                hasSeenActiveMeeting: true
            )
        )
    }

    func testPairingRequiredWithoutPriorActiveMeetingStaysHidden() {
        XCTAssertFalse(
            policy.shouldShowOverlay(
                state: .pairingRequired,
                isInActiveMeeting: false,
                hasSeenActiveMeeting: false
            )
        )
    }

    func testErrorAfterPriorActiveMeetingRemainsVisible() {
        XCTAssertTrue(
            policy.shouldShowOverlay(
                state: .error("Teams did not confirm mute state"),
                isInActiveMeeting: false,
                hasSeenActiveMeeting: true
            )
        )
    }

    func testUnavailableAndDisconnectedStayHiddenBeforeActiveMeeting() {
        XCTAssertFalse(
            policy.shouldShowOverlay(
                state: .apiUnavailable("Microsoft Teams is not running"),
                isInActiveMeeting: false,
                hasSeenActiveMeeting: false
            )
        )
        XCTAssertFalse(
            policy.shouldShowOverlay(
                state: .disconnected,
                isInActiveMeeting: false,
                hasSeenActiveMeeting: false
            )
        )
    }
}
