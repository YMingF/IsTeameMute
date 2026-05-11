import AppKit
import Foundation

public protocol TeamsRunningDetecting: Sendable {
    func isTeamsRunning() -> Bool
}

public struct TeamsProcessDetector: TeamsRunningDetecting {
    private let bundleIdentifiers = [
        "com.microsoft.teams",
        "com.microsoft.teams2"
    ]

    public init() {}

    public func isTeamsRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            guard let bundleIdentifier = app.bundleIdentifier else {
                return false
            }
            return bundleIdentifiers.contains(bundleIdentifier)
        }
    }
}
