import Combine
import Foundation

@MainActor
public final class MutedSpeechDetector: ObservableObject {
    @Published public private(set) var isWarningActive = false
    @Published public private(set) var hasAudibleInput = false
    @Published public private(set) var smoothedLevel: Float = 0

    private let activationThreshold: Float
    private let releaseThreshold: Float
    private let activationDuration: TimeInterval
    private let releaseDuration: TimeInterval
    private let smoothingFactor: Float
    private var loudSince: Date?
    private var quietSince: Date?

    public init(
        activationThreshold: Float = 0.20,
        releaseThreshold: Float = 0.08,
        activationDuration: TimeInterval = 1.20,
        releaseDuration: TimeInterval = 0.35,
        smoothingFactor: Float = 0.18
    ) {
        self.activationThreshold = activationThreshold
        self.releaseThreshold = releaseThreshold
        self.activationDuration = activationDuration
        self.releaseDuration = releaseDuration
        self.smoothingFactor = min(1, max(0, smoothingFactor))
    }

    public func update(level: Float, shouldDetect: Bool, now: Date = Date()) {
        guard shouldDetect else {
            reset()
            return
        }

        smoothedLevel = smoothedLevel + (min(1, max(0, level)) - smoothedLevel) * smoothingFactor

        if smoothedLevel >= activationThreshold {
            hasAudibleInput = true
            quietSince = nil
            if loudSince == nil {
                loudSince = now
            }
            if let loudSince, now.timeIntervalSince(loudSince) >= activationDuration {
                isWarningActive = true
            }
            return
        }

        if !isWarningActive {
            loudSince = nil
            quietSince = nil
            hasAudibleInput = false
        }

        if smoothedLevel <= releaseThreshold {
            hasAudibleInput = false
            loudSince = nil
            if quietSince == nil {
                quietSince = now
            }
            if let quietSince, now.timeIntervalSince(quietSince) >= releaseDuration {
                isWarningActive = false
            }
        }
    }

    public func reset() {
        loudSince = nil
        quietSince = nil
        smoothedLevel = 0
        hasAudibleInput = false
        isWarningActive = false
    }
}
