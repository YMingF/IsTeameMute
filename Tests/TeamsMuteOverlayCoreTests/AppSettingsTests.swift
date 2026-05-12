import XCTest
@testable import TeamsMuteOverlayCore

final class AppSettingsTests: XCTestCase {
    func testLaunchWhenTeamsMeetingStartsDefaultsToEnabled() {
        let suiteName = "AppSettingsTests.default.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)

        XCTAssertTrue(settings.launchWhenTeamsMeetingStarts)
    }

    func testLaunchWhenTeamsMeetingStartsPersistsChanges() {
        let suiteName = "AppSettingsTests.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        settings.launchWhenTeamsMeetingStarts = false

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertFalse(reloaded.launchWhenTeamsMeetingStarts)
    }
}
