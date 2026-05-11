import Combine
import Foundation

@MainActor
public final class MutedSpeechDetector: ObservableObject {
    @Published public private(set) var isWarningActive = false

    private let threshold: Float
    private let activationDuration: TimeInterval
    private let releaseDuration: TimeInterval
    private var loudSince: Date?
    private var quietSince: Date?

    public init(
        threshold: Float = 0.10,
        activationDuration: TimeInterval = 0.85,
        releaseDuration: TimeInterval = 0.22
    ) {
        self.threshold = threshold
        self.activationDuration = activationDuration
        self.releaseDuration = releaseDuration
    }

    public func update(level: Float, shouldDetect: Bool, now: Date = Date()) {
        guard shouldDetect else {
            reset()
            return
        }

        if level >= threshold {
            quietSince = nil
            if loudSince == nil {
                loudSince = now
            }
            if let loudSince, now.timeIntervalSince(loudSince) >= activationDuration {
                isWarningActive = true
            }
            return
        }

        loudSince = nil
        if quietSince == nil {
            quietSince = now
        }
        if let quietSince, now.timeIntervalSince(quietSince) >= releaseDuration {
            isWarningActive = false
        }
    }

    public func reset() {
        loudSince = nil
        quietSince = nil
        isWarningActive = false
    }
}
