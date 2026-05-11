import Foundation
import TeamsMuteOverlayCore

struct SpikeOptions {
    var shouldPair = false
    var shouldToggle = false
    var shouldMonitor = false
    var timeoutSeconds: Double = 30
    var clearToken = false
}

func parseOptions(arguments: [String]) -> SpikeOptions {
    var options = SpikeOptions()
    var index = 1

    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--pair":
            options.shouldPair = true
        case "--toggle":
            options.shouldToggle = true
        case "--monitor":
            options.shouldMonitor = true
        case "--clear-token":
            options.clearToken = true
        case "--timeout":
            if index + 1 < arguments.count, let timeout = Double(arguments[index + 1]) {
                options.timeoutSeconds = timeout
                index += 1
            }
        case "--help", "-h":
            printHelpAndExit()
        default:
            print("Unknown argument: \(argument)")
            printHelpAndExit(code: 2)
        }

        index += 1
    }

    return options
}

func printHelpAndExit(code: Int32 = 0) -> Never {
    print("""
    Usage:
      teams-mute-spike [--pair] [--toggle] [--monitor] [--timeout seconds] [--clear-token]

    Examples:
      swift run teams-mute-spike --pair
      swift run teams-mute-spike --toggle
      swift run teams-mute-spike --monitor --timeout 120

    This validates Microsoft Teams local Third-party app API availability.
    It does not fall back to system microphone state.
    """)
    exit(code)
}

@main
struct TeamsMuteSpike {
    static func main() async {
        let options = parseOptions(arguments: CommandLine.arguments)
        let tokenStore = KeychainTokenStore()

        if options.clearToken {
            do {
                try tokenStore.deleteToken()
                print("Deleted stored Teams API token from Keychain.")
            } catch {
                print("Failed to delete token: \(error.localizedDescription)")
                exit(1)
            }
        }

        let detector = TeamsProcessDetector()
        guard detector.isTeamsRunning() else {
            print("方案 2 在当前 Teams/公司策略下不可做")
            print("Reason: Microsoft Teams is not running.")
            exit(1)
        }

        let client = TeamsApiClient()
        let storedToken = tokenStore.loadToken()
        let token = storedToken ?? UUID().uuidString
        let deadline = Date().addingTimeInterval(options.timeoutSeconds)
        var sawMeetingState = false
        var sawTokenRefresh = false
        var sentPairProbe = false
        var sentToggle = false

        print("Connecting to Teams local API on ws://localhost:8124 ...")
        print(storedToken == nil ? "No stored token; using temporary token and waiting for pairing." : "Using stored Keychain token.")
        client.connect(token: token)

        let timeoutTask = Task {
            while Date() < deadline {
                try? await Task.sleep(for: .milliseconds(250))
            }

            print("方案 2 在当前 Teams/公司策略下不可做")
            print("Reason: timed out before Teams returned required meeting/mic state.")
            exit(1)
        }

        for await event in client.events {
            switch event {
            case .connected:
                print("Connected.")
            case .meetingUpdate(let update):
                printMeetingUpdate(update)
                if update.meetingState != nil {
                    sawMeetingState = true
                }

                if options.shouldPair,
                   !sentPairProbe,
                   update.meetingPermissions?.canPair == true {
                    sentPairProbe = true
                    do {
                        let requestId = try await client.sendPairingProbe()
                        print("Sent pairing probe requestId=\(requestId). Approve the Teams Allow/Block prompt.")
                    } catch {
                        print("Failed to send pairing probe: \(error.localizedDescription)")
                    }
                }

                if options.shouldToggle,
                   !sentToggle,
                   update.meetingState?.isInMeeting == true,
                   update.meetingPermissions?.canToggleMute == true {
                    sentToggle = true
                    do {
                        let requestId = try await client.toggleMute()
                        print("Sent toggle-mute requestId=\(requestId). Waiting for Teams confirmation update.")
                    } catch {
                        print("Failed to send toggle-mute: \(error.localizedDescription)")
                    }
                }

                if sawMeetingState && (!options.shouldPair || sawTokenRefresh) && (!options.shouldToggle || sentToggle) && !options.shouldMonitor {
                    print("Feasibility gate passed for the observable API path.")
                    timeoutTask.cancel()
                    exit(0)
                }
            case .tokenRefresh(let token):
                sawTokenRefresh = true
                do {
                    try tokenStore.saveToken(token)
                    print("Received tokenRefresh and saved it to Keychain.")
                } catch {
                    print("Received tokenRefresh but failed to save it: \(error.localizedDescription)")
                }
            case .serviceResponse(let response):
                print("Service response requestId=\(response.requestId): \(response.response)")
            case .disconnected(let reason):
                print("方案 2 在当前 Teams/公司策略下不可做")
                print("Reason: Teams API disconnected: \(reason)")
                timeoutTask.cancel()
                exit(1)
            }
        }
    }

    private static func printMeetingUpdate(_ update: MeetingUpdate) {
        if let state = update.meetingState {
            print("meetingState: inMeeting=\(state.isInMeeting), muted=\(state.isMuted), video=\(state.isVideoOn)")
        }

        if let permissions = update.meetingPermissions {
            print("meetingPermissions: canPair=\(permissions.canPair), canToggleMute=\(permissions.canToggleMute)")
        }
    }
}
