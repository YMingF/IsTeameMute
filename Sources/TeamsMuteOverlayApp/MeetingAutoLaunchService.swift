import Foundation
import ServiceManagement

protocol MeetingAutoLaunchServicing {
    func register() throws
    func unregister() throws
}

struct MeetingAutoLaunchService: MeetingAutoLaunchServicing {
    func register() throws {
        let service = service()
        try? service.unregister()
        try service.register()
    }

    func unregister() throws {
        try service().unregister()
    }

    private func service() -> SMAppService {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.local.TeamsMuteOverlay"
        return SMAppService.loginItem(identifier: "\(bundleIdentifier).MeetingHelper")
    }
}
