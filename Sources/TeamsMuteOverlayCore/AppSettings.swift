import Combine
import Foundation

public final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published public var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published public var overlaySize: Double {
        didSet { defaults.set(overlaySize, forKey: Keys.overlaySize) }
    }

    @Published public var pulseEnabled: Bool {
        didSet { defaults.set(pulseEnabled, forKey: Keys.pulseEnabled) }
    }

    @Published public var mutedSpeechWarningEnabled: Bool {
        didSet { defaults.set(mutedSpeechWarningEnabled, forKey: Keys.mutedSpeechWarningEnabled) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)

        let savedSize = defaults.double(forKey: Keys.overlaySize)
        self.overlaySize = savedSize > 0 ? savedSize : 96
        self.pulseEnabled = defaults.bool(forKey: Keys.pulseEnabled)
        self.mutedSpeechWarningEnabled = defaults.object(forKey: Keys.mutedSpeechWarningEnabled) as? Bool ?? true
    }

    public func resetOverlayPosition() {
        defaults.removeObject(forKey: Keys.overlayX)
        defaults.removeObject(forKey: Keys.overlayY)
    }

    public func loadOverlayOrigin(defaultScreenFrame: CGRect, overlaySize: CGFloat) -> CGPoint {
        let savedX = defaults.object(forKey: Keys.overlayX) as? Double
        let savedY = defaults.object(forKey: Keys.overlayY) as? Double
        if let savedX, let savedY {
            return CGPoint(x: savedX, y: savedY)
        }

        return CGPoint(
            x: defaultScreenFrame.maxX - overlaySize - 24,
            y: defaultScreenFrame.minY + 48
        )
    }

    public func saveOverlayOrigin(_ point: CGPoint) {
        defaults.set(point.x, forKey: Keys.overlayX)
        defaults.set(point.y, forKey: Keys.overlayY)
    }

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let overlaySize = "overlaySize"
        static let pulseEnabled = "pulseEnabled"
        static let mutedSpeechWarningEnabled = "mutedSpeechWarningEnabled"
        static let overlayX = "overlayX"
        static let overlayY = "overlayY"
    }
}
