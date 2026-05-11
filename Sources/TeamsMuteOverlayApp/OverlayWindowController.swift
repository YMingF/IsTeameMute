import AppKit
import CoreGraphics
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
            mutedSpeechDetector: mutedSpeechDetector,
            shouldSuppressToggle: { [weak window] in
                window?.consumePendingDragSuppression() ?? false
            }
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.sharingType = .none
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

    func moveToActiveScreenIfNeeded() {
        guard let window else {
            return
        }

        guard let targetScreen = activeApplicationScreen() ?? currentMouseScreen() ?? NSScreen.main else {
            return
        }

        let currentMidpoint = CGPoint(x: window.frame.midX, y: window.frame.midY)
        guard !targetScreen.frame.contains(currentMidpoint) else {
            return
        }

        let targetFrame = targetScreen.visibleFrame
        let currentScreen = NSScreen.screens.first(where: { $0.frame.contains(currentMidpoint) })
        let currentFrame = currentScreen?.visibleFrame ?? targetFrame
        let relativeX = currentFrame.width > window.frame.width
            ? (window.frame.minX - currentFrame.minX) / (currentFrame.width - window.frame.width)
            : 1
        let relativeY = currentFrame.height > window.frame.height
            ? (window.frame.minY - currentFrame.minY) / (currentFrame.height - window.frame.height)
            : 0
        let clampedX = min(1, max(0, relativeX))
        let clampedY = min(1, max(0, relativeY))
        let origin = CGPoint(
            x: targetFrame.minX + (targetFrame.width - window.frame.width) * clampedX,
            y: targetFrame.minY + (targetFrame.height - window.frame.height) * clampedY
        )

        window.setFrameOrigin(origin)
        settings.saveOverlayOrigin(origin)
    }

    private func activeApplicationScreen() -> NSScreen? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else {
            return nil
        }

        for windowInfo in windowList {
            guard (windowInfo[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (windowInfo[kCGWindowLayer as String] as? Int) == 0,
                  let boundsInfo = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo as CFDictionary),
                  bounds.width > 1,
                  bounds.height > 1
            else {
                continue
            }

            let midpoint = CGPoint(x: bounds.midX, y: bounds.midY)
            if let screen = NSScreen.screens.first(where: { $0.cgDisplayBounds.contains(midpoint) }) {
                return screen
            }
        }

        return nil
    }

    private func currentMouseScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
    }

    func windowDidMove(_ notification: Notification) {
        guard let origin = window?.frame.origin else {
            return
        }
        settings.saveOverlayOrigin(origin)
    }
}

private extension NSScreen {
    var cgDisplayBounds: CGRect {
        guard let displayID = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return frame
        }

        return CGDisplayBounds(displayID)
    }
}

final class DraggablePanel: NSPanel {
    private let dragThreshold: CGFloat = 4
    private var mouseDownLocation: NSPoint?
    private var didDragSinceMouseDown = false
    private var shouldSuppressNextClick = false

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = event.locationInWindow
        didDragSinceMouseDown = false
        shouldSuppressNextClick = false
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if let mouseDownLocation {
            let location = event.locationInWindow
            let deltaX = location.x - mouseDownLocation.x
            let deltaY = location.y - mouseDownLocation.y
            if hypot(deltaX, deltaY) >= dragThreshold {
                didDragSinceMouseDown = true
            }
        }
        super.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        shouldSuppressNextClick = didDragSinceMouseDown
        mouseDownLocation = nil
        didDragSinceMouseDown = false
        super.mouseUp(with: event)
    }

    func consumePendingDragSuppression() -> Bool {
        let shouldSuppress = shouldSuppressNextClick
        shouldSuppressNextClick = false
        return shouldSuppress
    }
}
