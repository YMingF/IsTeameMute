import Foundation

public enum TeamsApiEvent: Equatable, Sendable {
    case connected
    case meetingUpdate(MeetingUpdate)
    case tokenRefresh(String)
    case serviceResponse(ServiceResponse)
    case disconnected(String)
}

public enum TeamsApiClientError: Error, LocalizedError {
    case notConnected
    case invalidTextFrame

    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Teams API socket is not connected"
        case .invalidTextFrame:
            return "Teams API returned a non-text frame"
        }
    }
}

public protocol TeamsApiClienting: AnyObject, Sendable {
    var events: AsyncStream<TeamsApiEvent> { get }
    func connect(token: String)
    func disconnect()
    func disconnect(reason: String)
    func toggleMute() async throws -> Int
    func sendPairingProbe() async throws -> Int
}

public final class TeamsApiClient: NSObject, TeamsApiClienting, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let configuration: TeamsApiConfiguration
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let eventContinuation: AsyncStream<TeamsApiEvent>.Continuation
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var requestId = 0
    private let lock = NSLock()

    public let events: AsyncStream<TeamsApiEvent>

    public init(configuration: TeamsApiConfiguration = TeamsApiConfiguration()) {
        self.configuration = configuration
        var continuation: AsyncStream<TeamsApiEvent>.Continuation!
        self.events = AsyncStream { streamContinuation in
            continuation = streamContinuation
        }
        self.eventContinuation = continuation
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    public func connect(token: String) {
        disconnect(reason: "reconnect")
        let url = configuration.socketURL(token: token)
        let task = session!.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        receiveLoop(task: task)
    }

    public func disconnect(reason: String = "manual disconnect") {
        lock.lock()
        let task = webSocketTask
        webSocketTask = nil
        lock.unlock()

        task?.cancel(with: .normalClosure, reason: Data(reason.utf8))
    }

    public func disconnect() {
        disconnect(reason: "manual disconnect")
    }

    @discardableResult
    public func toggleMute() async throws -> Int {
        try await send(action: "toggle-mute")
    }

    @discardableResult
    public func sendPairingProbe() async throws -> Int {
        try await send(action: "send-reaction", parameters: ["type": "like"])
    }

    @discardableResult
    public func send(action: String, parameters: [String: String] = [:]) async throws -> Int {
        let sendState = try nextSendState()
        let task = sendState.task
        let currentRequestId = sendState.requestId

        let request = ServiceRequest(action: action, requestId: currentRequestId, parameters: parameters)
        let data = try encoder.encode(request)
        guard let text = String(data: data, encoding: .utf8) else {
            throw TeamsApiClientError.invalidTextFrame
        }

        try await task.send(.string(text))
        return currentRequestId
    }

    private func nextSendState() throws -> (task: URLSessionWebSocketTask, requestId: Int) {
        lock.lock()
        defer { lock.unlock() }

        guard let task = webSocketTask else {
            throw TeamsApiClientError.notConnected
        }

        requestId += 1
        return (task, requestId)
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        eventContinuation.yield(.connected)
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let message = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "\(closeCode.rawValue)"
        eventContinuation.yield(.disconnected(message))
    }

    private func receiveLoop(task: URLSessionWebSocketTask) {
        task.receive { [weak self, weak task] result in
            guard let self, let task else {
                return
            }

            switch result {
            case .success(let message):
                self.handle(message: message)
                self.receiveLoop(task: task)
            case .failure(let error):
                self.eventContinuation.yield(.disconnected(error.localizedDescription))
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        let data: Data

        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let frameData):
            data = frameData
        @unknown default:
            eventContinuation.yield(.disconnected(TeamsApiClientError.invalidTextFrame.localizedDescription))
            return
        }

        do {
            let message = try decoder.decode(TeamsMessage.self, from: data)
            if let update = message.meetingUpdate {
                eventContinuation.yield(.meetingUpdate(update))
            }
            if let token = message.tokenRefresh {
                eventContinuation.yield(.tokenRefresh(token))
            }
            if let requestId = message.requestId, let response = message.response {
                eventContinuation.yield(.serviceResponse(ServiceResponse(requestId: requestId, response: response)))
            }
        } catch {
            eventContinuation.yield(.disconnected("Invalid Teams API payload: \(error.localizedDescription)"))
        }
    }
}
