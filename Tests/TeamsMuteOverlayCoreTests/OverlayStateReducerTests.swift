import XCTest
@testable import TeamsMuteOverlayCore

final class OverlayStateReducerTests: XCTestCase {
    private let reducer = OverlayStateReducer()

    func testPairingRequiredWhenCanPairWithoutStoredToken() {
        let update = MeetingUpdate(
            meetingPermissions: MeetingPermissions(canPair: true)
        )

        XCTAssertEqual(reducer.reduce(update: update, hasStoredToken: false), .pairingRequired)
    }

    func testPairingRequiredWhenCanPairEvenWithStoredToken() {
        let update = MeetingUpdate(
            meetingPermissions: MeetingPermissions(canPair: true)
        )

        XCTAssertEqual(reducer.reduce(update: update, hasStoredToken: true), .pairingRequired)
    }

    func testNotInMeetingWhenStateSaysNoMeeting() {
        let update = MeetingUpdate(
            meetingState: MeetingState(isMuted: false, isInMeeting: false),
            meetingPermissions: MeetingPermissions(canToggleMute: false)
        )

        XCTAssertEqual(reducer.reduce(update: update, hasStoredToken: true), .notInMeeting)
    }

    func testMutedAndUnmutedStatesComeFromTeamsMeetingState() {
        let mutedUpdate = MeetingUpdate(meetingState: MeetingState(isMuted: true, isInMeeting: true))
        let unmutedUpdate = MeetingUpdate(meetingState: MeetingState(isMuted: false, isInMeeting: true))

        XCTAssertEqual(reducer.reduce(update: mutedUpdate, hasStoredToken: true), .muted)
        XCTAssertEqual(reducer.reduce(update: unmutedUpdate, hasStoredToken: true), .unmuted)
    }

    func testSyncingOnlyStartsFromKnownMuteStates() {
        XCTAssertEqual(reducer.syncingState(from: .muted), .syncing(previous: .muted))
        XCTAssertEqual(reducer.syncingState(from: .unmuted), .syncing(previous: .unmuted))
        XCTAssertNil(reducer.syncingState(from: .notInMeeting))
        XCTAssertNil(reducer.syncingState(from: .disconnected))
    }

    func testToggleConfirmationRequiresOppositeMuteState() {
        let unmutedUpdate = MeetingUpdate(meetingState: MeetingState(isMuted: false, isInMeeting: true))
        let mutedUpdate = MeetingUpdate(meetingState: MeetingState(isMuted: true, isInMeeting: true))
        let notInMeeting = MeetingUpdate(meetingState: MeetingState(isMuted: false, isInMeeting: false))

        XCTAssertTrue(reducer.didConfirmToggle(previous: .muted, update: unmutedUpdate))
        XCTAssertTrue(reducer.didConfirmToggle(previous: .unmuted, update: mutedUpdate))
        XCTAssertFalse(reducer.didConfirmToggle(previous: .muted, update: mutedUpdate))
        XCTAssertFalse(reducer.didConfirmToggle(previous: .muted, update: notInMeeting))
    }
}
