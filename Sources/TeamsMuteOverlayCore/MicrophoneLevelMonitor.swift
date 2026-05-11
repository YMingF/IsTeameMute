import AVFAudio
import AVFoundation
import Combine
import Foundation

@MainActor
public final class MicrophoneLevelMonitor: ObservableObject {
    @Published public private(set) var level: Float = 0
    @Published public private(set) var permissionDenied = false

    private var engine: AVAudioEngine?
    private var isRunning = false
    private var isEnabled = false
    private var isRequestingPermission = false

    public init() {}

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        enabled ? start() : stop()
    }

    public func start() {
        isEnabled = true
        guard !isRunning else {
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startEngine()
        case .notDetermined:
            requestMicrophonePermission()
        case .denied, .restricted:
            permissionDenied = true
            level = 0
        @unknown default:
            permissionDenied = true
            level = 0
        }
    }

    public func stop() {
        isEnabled = false
        isRequestingPermission = false
        stopEngine()
        level = 0
    }

    private func requestMicrophonePermission() {
        guard !isRequestingPermission else {
            return
        }

        isRequestingPermission = true
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                guard let self else {
                    return
                }

                self.isRequestingPermission = false
                guard self.isEnabled else {
                    return
                }

                if granted {
                    self.startEngine()
                } else {
                    self.permissionDenied = true
                    self.level = 0
                }
            }
        }
    }

    private func startEngine() {
        stopEngine()

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
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRunning = false
            self.engine = nil
            permissionDenied = true
        }
    }

    private func stopEngine() {
        isRunning = false
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }
}
