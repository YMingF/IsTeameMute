import Combine
import Foundation

public struct TeamsOverlaySettings: Sendable {
    public var autoPair: Bool
    public var reconnectDelay: Duration
    public var commandTimeout: Duration

    public init(
        autoPair: Bool = true,
        reconnectDelay: Duration = .seconds(2),
        commandTimeout: Duration = .milliseconds(1500)
    ) {
        self.autoPair = autoPair
        self.reconnectDelay = reconnectDelay
        self.commandTimeout = commandTimeout
    }
}

@MainActor
public final class TeamsOverlayController: ObservableObject {
    @Published public private(set) var state: TeamsOverlayState = .disconnected
    @Published public private(set) var lastMeetingUpdate: MeetingUpdate?
    @Published public private(set) var lastServiceResponse: ServiceResponse?
    @Published public private(set) var lastTokenRefresh: String?
    @Published public var microphonePulseEnabled = false

    private let apiClient: TeamsApiClienting
    private let tokenStore: TokenStore
    private let detector: TeamsRunningDetecting
    private let reducer: OverlayStateReducer
    private let settings: TeamsOverlaySettings
    private var eventTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var commandTimeoutTask: Task<Void, Never>?
    private var didAutoPairForCurrentConnection = false

    public init(
        apiClient: TeamsApiClienting = TeamsApiClient(),
        tokenStore: TokenStore = KeychainTokenStore(),
        detector: TeamsRunningDetecting = TeamsProcessDetector(),
        reducer: OverlayStateReducer = OverlayStateReducer(),
        settings: TeamsOverlaySettings = TeamsOverlaySettings()
    ) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.detector = detector
        self.reducer = reducer
        self.settings = settings
    }

    deinit {
        eventTask?.cancel()
        reconnectTask?.cancel()
        commandTimeoutTask?.cancel()
        apiClient.disconnect()
    }

    public func start() {
        guard eventTask == nil else {
            return
        }

        eventTask = Task { [weak self] in
            guard let self else {
                return
            }

            for await event in apiClient.events {
                await self.handle(event: event)
            }
        }

        connect()
    }

    public func connect() {
        guard detector.isTeamsRunning() else {
            state = .apiUnavailable("Microsoft Teams is not running")
            scheduleReconnect()
            return
        }

        let token = tokenStore.loadToken() ?? UUID().uuidString
        state = .disconnected
        didAutoPairForCurrentConnection = false
        apiClient.connect(token: token)
    }

    public func disconnectAndClearToken() {
        commandTimeoutTask?.cancel()
        reconnectTask?.cancel()
        apiClient.disconnect()
        try? tokenStore.deleteToken()
        state = .pairingRequired
    }

    public func requestPairing() {
        Task {
            do {
                _ = try await apiClient.sendPairingProbe()
            } catch {
                state = .error("Pairing probe failed: \(error.localizedDescription)")
                scheduleReconnect()
            }
        }
    }

    public func toggleMute() {
        guard let syncingState = reducer.syncingState(from: state) else {
            return
        }

        state = syncingState

        Task {
            do {
                _ = try await apiClient.toggleMute()
                startCommandTimeout()
            } catch {
                state = .error("Mute toggle failed: \(error.localizedDescription)")
                scheduleReconnect()
            }
        }
    }

    private func handle(event: TeamsApiEvent) async {
        switch event {
        case .connected:
            state = .disconnected
        case .meetingUpdate(let update):
            handle(update: update)
        case .tokenRefresh(let token):
            do {
                try tokenStore.saveToken(token)
                lastTokenRefresh = token
            } catch {
                state = .error("Could not save Teams API token: \(error.localizedDescription)")
            }
        case .serviceResponse(let response):
            lastServiceResponse = response
        case .disconnected(let reason):
            state = .apiUnavailable("Teams API unavailable: \(reason)")
            scheduleReconnect()
        }
    }

    private func handle(update: MeetingUpdate) {
        lastMeetingUpdate = update

        if update.meetingState == nil {
            if update.meetingPermissions?.canPair == true {
                state = .pairingRequired
                if settings.autoPair && !didAutoPairForCurrentConnection {
                    didAutoPairForCurrentConnection = true
                    requestPairing()
                }
            }
            return
        }

        if case .syncing(let previous) = state, reducer.didConfirmToggle(previous: previous, update: update) {
            commandTimeoutTask?.cancel()
            state = reducer.reduce(update: update, hasStoredToken: tokenStore.loadToken() != nil)
            return
        }

        if case .syncing = state {
            return
        }

        let nextState = reducer.reduce(update: update, hasStoredToken: tokenStore.loadToken() != nil)
        state = nextState

        if nextState == .pairingRequired && settings.autoPair && !didAutoPairForCurrentConnection {
            didAutoPairForCurrentConnection = true
            requestPairing()
        }
    }

    private func startCommandTimeout() {
        commandTimeoutTask?.cancel()
        commandTimeoutTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await Task.sleep(for: settings.commandTimeout)
            } catch {
                return
            }

            await MainActor.run {
                if case .syncing = self.state {
                    self.state = .error("Teams did not confirm mute state within 1.5 seconds")
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await Task.sleep(for: settings.reconnectDelay)
            } catch {
                return
            }

            await MainActor.run {
                self.connect()
            }
        }
    }
}
