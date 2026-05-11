import XCTest
@testable import TeamsMuteOverlayCore

@MainActor
final class TeamsOverlayControllerTests: XCTestCase {
    func testStartReportsApiUnavailableWhenTeamsIsNotRunning() {
        let client = FakeTeamsApiClient()
        let controller = TeamsOverlayController(
            apiClient: client,
            tokenStore: MemoryTokenStore(),
            detector: FakeTeamsDetector(isRunning: false),
            settings: TeamsOverlaySettings(reconnectDelay: .seconds(60), commandTimeout: .milliseconds(100))
        )

        controller.start()

        guard case .apiUnavailable(let reason) = controller.state else {
            return XCTFail("Expected apiUnavailable, got \(controller.state)")
        }
        XCTAssertEqual(reason, "Microsoft Teams is not running")
    }

    func testToggleTimeoutMovesToErrorWhenTeamsDoesNotConfirm() async {
        let client = FakeTeamsApiClient()
        let controller = TeamsOverlayController(
            apiClient: client,
            tokenStore: MemoryTokenStore(token: "stored"),
            detector: FakeTeamsDetector(isRunning: true),
            settings: TeamsOverlaySettings(reconnectDelay: .seconds(60), commandTimeout: .milliseconds(50))
        )

        controller.start()
        client.emit(.meetingUpdate(MeetingUpdate(meetingState: MeetingState(isMuted: false, isInMeeting: true))))
        await waitForState(.unmuted, controller: controller)

        controller.toggleMute()
        XCTAssertEqual(controller.state, .syncing(previous: .unmuted))

        await waitForError(
            "Teams did not confirm mute state within 1.5 seconds",
            controller: controller
        )
    }

    func testToggleConfirmationMovesToMuted() async {
        let client = FakeTeamsApiClient()
        let controller = TeamsOverlayController(
            apiClient: client,
            tokenStore: MemoryTokenStore(token: "stored"),
            detector: FakeTeamsDetector(isRunning: true),
            settings: TeamsOverlaySettings(reconnectDelay: .seconds(60), commandTimeout: .milliseconds(500))
        )

        controller.start()
        client.emit(.meetingUpdate(MeetingUpdate(meetingState: MeetingState(isMuted: false, isInMeeting: true))))
        await waitForState(.unmuted, controller: controller)

        controller.toggleMute()
        client.emit(.meetingUpdate(MeetingUpdate(meetingState: MeetingState(isMuted: true, isInMeeting: true))))

        await waitForState(.muted, controller: controller)
    }

    private func waitForState(
        _ expected: TeamsOverlayState,
        controller: TeamsOverlayController,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<20 {
            if controller.state == expected {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }

        XCTFail("Expected \(expected), got \(controller.state)", file: file, line: line)
    }

    private func waitForError(
        _ expectedMessage: String,
        controller: TeamsOverlayController,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<20 {
            if case .error(let message) = controller.state {
                XCTAssertEqual(message, expectedMessage, file: file, line: line)
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }

        XCTFail("Expected error, got \(controller.state)", file: file, line: line)
    }
}

private struct FakeTeamsDetector: TeamsRunningDetecting {
    var isRunning: Bool

    func isTeamsRunning() -> Bool {
        isRunning
    }
}

private final class FakeTeamsApiClient: TeamsApiClienting, @unchecked Sendable {
    private let continuation: AsyncStream<TeamsApiEvent>.Continuation
    let events: AsyncStream<TeamsApiEvent>
    private(set) var connectTokens: [String] = []
    private(set) var disconnectReasons: [String] = []
    private(set) var toggleCount = 0
    private(set) var pairingProbeCount = 0

    init() {
        var continuation: AsyncStream<TeamsApiEvent>.Continuation!
        self.events = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation
    }

    func connect(token: String) {
        connectTokens.append(token)
        emit(.connected)
    }

    func disconnect(reason: String) {
        disconnectReasons.append(reason)
    }

    func disconnect() {
        disconnect(reason: "manual disconnect")
    }

    func toggleMute() async throws -> Int {
        toggleCount += 1
        return toggleCount
    }

    func sendPairingProbe() async throws -> Int {
        pairingProbeCount += 1
        return pairingProbeCount
    }

    func emit(_ event: TeamsApiEvent) {
        continuation.yield(event)
    }
}
