import AVFAudio
import Combine
import Foundation

@MainActor
public final class MicrophoneLevelMonitor: ObservableObject {
    @Published public private(set) var level: Float = 0
    @Published public private(set) var permissionDenied = false

    private var engine: AVAudioEngine?
    private var isRunning = false

    public init() {}

    public func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    public func start() {
        guard !isRunning else {
            return
        }

        startEngine()
    }

    public func stop() {
        isRunning = false
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        level = 0
    }

    private func startEngine() {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else {
                return
            }

            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else {
                return
            }

            var peak: Float = 0
            for index in 0..<frameLength {
                peak = max(peak, abs(channelData[index]))
            }

            Task { @MainActor in
                self?.level = min(1, peak)
            }
        }

        do {
            try engine.start()
            self.engine = engine
            isRunning = true
            permissionDenied = false
        } catch {
            permissionDenied = true
        }
    }
}
