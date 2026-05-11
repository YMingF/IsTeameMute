import AppKit
import SwiftUI
import TeamsMuteOverlayCore

@MainActor
final class OverlayWindowController: NSWindowController, NSWindowDelegate {
    private let settings: AppSettings
    private let scalePaddingMultiplier: CGFloat = 0.28

    init(
        controller: TeamsOverlayController,
        settings: AppSettings,
        microphoneMonitor: MicrophoneLevelMonitor,
        mutedSpeechDetector: MutedSpeechDetector
    ) {
        self.settings = settings

        let size = CGFloat(settings.overlaySize)
        let windowSize = size * (1 + scalePaddingMultiplier)
        let screenFrame = NSScreen.main?.visibleFrame ?? .init(x: 0, y: 0, width: 1280, height: 800)
        let origin = settings.loadOverlayOrigin(defaultScreenFrame: screenFrame, overlaySize: windowSize)
        let window = DraggablePanel(
            contentRect: NSRect(x: origin.x, y: origin.y, width: windowSize, height: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let view = OverlayButtonView(
            controller: controller,
            settings: settings,
            microphoneMonitor: microphoneMonitor,
            mutedSpeechDetector: mutedSpeechDetector
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: view)

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.orderFrontRegardless()
    }

    func resetPosition() {
        guard let window else {
            return
        }

        let size = CGFloat(settings.overlaySize)
        let windowSize = size * (1 + scalePaddingMultiplier)
        let screenFrame = NSScreen.main?.visibleFrame ?? .init(x: 0, y: 0, width: 1280, height: 800)
        let origin = settings.loadOverlayOrigin(defaultScreenFrame: screenFrame, overlaySize: windowSize)
        window.setFrame(NSRect(x: origin.x, y: origin.y, width: windowSize, height: windowSize), display: true)
    }

    func resize() {
        guard let window else {
            return
        }

        let size = CGFloat(settings.overlaySize)
        let windowSize = size * (1 + scalePaddingMultiplier)
        var frame = window.frame
        frame.size = CGSize(width: windowSize, height: windowSize)
        window.setFrame(frame, display: true)
    }

    func windowDidMove(_ notification: Notification) {
        guard let origin = window?.frame.origin else {
            return
        }
        settings.saveOverlayOrigin(origin)
    }
}

final class DraggablePanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
