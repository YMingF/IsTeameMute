import AppKit
import TeamsMuteOverlayCore

@main
struct TeamsMuteOverlayMeetingHelper {
    static func main() async {
        let detector = TeamsProcessDetector()
        let tokenStore = KeychainTokenStore()
        let apiClient = TeamsApiClient()

        while !Task.isCancelled {
            guard detector.isTeamsRunning(), let token = tokenStore.loadToken() else {
                try? await Task.sleep(for: .seconds(5))
                continue
            }

            apiClient.connect(token: token)
            for await event in apiClient.events {
                if case .meetingUpdate(let update) = event,
                   update.meetingState?.isInMeeting == true {
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.arguments = ["--auto-launched-for-teams-meeting"]
                    _ = try? await NSWorkspace.shared.openApplication(
                        at: mainAppURL(),
                        configuration: configuration
                    )
                    apiClient.disconnect()
                    try? await Task.sleep(for: .seconds(30))
                    break
                }

                if case .disconnected = event {
                    break
                }
            }

            apiClient.disconnect()
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private static func mainAppURL() -> URL {
        var url = Bundle.main.bundleURL
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        return url
    }
}
