import XCTest
@testable import TeamsMuteOverlayCore

@MainActor
final class MutedSpeechDetectorTests: XCTestCase {
    func testRequiresSustainedSmoothedLevelBeforeActivating() {
        let detector = MutedSpeechDetector(smoothingFactor: 1)
        let start = Date()

        detector.update(level: 0.5, shouldDetect: true, now: start)
        XCTAssertTrue(detector.hasAudibleInput)
        detector.update(level: 0.5, shouldDetect: true, now: start.addingTimeInterval(0.5))
        XCTAssertFalse(detector.isWarningActive)
        XCTAssertTrue(detector.hasAudibleInput)

        detector.update(level: 0.5, shouldDetect: true, now: start.addingTimeInterval(0.76))
        XCTAssertTrue(detector.isWarningActive)
    }

    func testShortNoiseDropsWithoutActivating() {
        let detector = MutedSpeechDetector(smoothingFactor: 1)
        let start = Date()

        detector.update(level: 0.5, shouldDetect: true, now: start)
        detector.update(level: 0.0, shouldDetect: true, now: start.addingTimeInterval(0.12))
        detector.update(level: 0.5, shouldDetect: true, now: start.addingTimeInterval(0.3))
        detector.update(level: 0.5, shouldDetect: true, now: start.addingTimeInterval(0.6))

        XCTAssertFalse(detector.isWarningActive)
    }

    func testReleaseUsesLowerThresholdAndDuration() {
        let detector = MutedSpeechDetector(smoothingFactor: 1)
        let start = Date()

        detector.update(level: 0.5, shouldDetect: true, now: start)
        detector.update(level: 0.5, shouldDetect: true, now: start.addingTimeInterval(0.76))
        XCTAssertTrue(detector.isWarningActive)

        detector.update(level: 0.08, shouldDetect: true, now: start.addingTimeInterval(0.8))
        detector.update(level: 0.08, shouldDetect: true, now: start.addingTimeInterval(1.2))
        XCTAssertTrue(detector.isWarningActive)

        detector.update(level: 0.0, shouldDetect: true, now: start.addingTimeInterval(1.25))
        detector.update(level: 0.0, shouldDetect: true, now: start.addingTimeInterval(1.51))
        XCTAssertFalse(detector.isWarningActive)
    }

    func testDisablingDetectionResetsWarningAndSmoothedLevel() {
        let detector = MutedSpeechDetector(smoothingFactor: 1)
        let start = Date()

        detector.update(level: 0.5, shouldDetect: true, now: start)
        detector.update(level: 0.5, shouldDetect: true, now: start.addingTimeInterval(0.76))
        XCTAssertTrue(detector.isWarningActive)
        XCTAssertGreaterThan(detector.smoothedLevel, 0)
        XCTAssertTrue(detector.hasAudibleInput)

        detector.update(level: 0.5, shouldDetect: false, now: start.addingTimeInterval(0.8))

        XCTAssertFalse(detector.isWarningActive)
        XCTAssertEqual(detector.smoothedLevel, 0)
        XCTAssertFalse(detector.hasAudibleInput)
    }
}
