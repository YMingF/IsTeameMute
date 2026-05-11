import AppKit
import Combine
import SwiftUI
import TeamsMuteOverlayCore

@main
struct TeamsMuteOverlayApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = TeamsOverlayController()
    private let settings = AppSettings()
    private let microphoneMonitor = MicrophoneLevelMonitor()
    private let mutedSpeechDetector = MutedSpeechDetector()
    private var statusItem: NSStatusItem?
    private var overlayWindowController: OverlayWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller.microphonePulseEnabled = settings.pulseEnabled
        updateMicrophoneMonitoring()
        setupStatusItem()
        setupOverlay()
        bindSettings()
        controller.start()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Teams"
        statusItem = item
        updateMenu()
    }

    private func setupOverlay() {
        overlayWindowController = OverlayWindowController(
            controller: controller,
            settings: settings,
            microphoneMonitor: microphoneMonitor,
            mutedSpeechDetector: mutedSpeechDetector
        )
        overlayWindowController?.show()
    }

    private func bindSettings() {
        settings.$pulseEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.controller.microphonePulseEnabled = enabled
                self?.updateMicrophoneMonitoring()
                self?.updateMenu()
            }
            .store(in: &cancellables)

        settings.$mutedSpeechWarningEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMicrophoneMonitoring()
                self?.updateMutedSpeechDetector()
                self?.updateMenu()
            }
            .store(in: &cancellables)

        microphoneMonitor.$level
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMutedSpeechDetector()
            }
            .store(in: &cancellables)

        controller.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.statusItem?.button?.title = "Teams \(state.shortLabel)"
                self?.updateMicrophoneMonitoring()
                self?.updateMutedSpeechDetector()
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }

    private var cancellables: Set<AnyCancellableBox> = []

    private func updateMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: controller.state.detail, action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let pairItem = NSMenuItem(title: "重新配对 Teams API", action: #selector(requestPairing), keyEquivalent: "p")
        pairItem.target = self
        menu.addItem(pairItem)

        let clearItem = NSMenuItem(title: "断开并清除 token", action: #selector(disconnectAndClearToken), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        let resetItem = NSMenuItem(title: "重置悬浮窗位置", action: #selector(resetOverlayPosition), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        let pulseItem = NSMenuItem(title: "音量 Pulse", action: #selector(togglePulse), keyEquivalent: "")
        pulseItem.target = self
        pulseItem.state = settings.pulseEnabled ? .on : .off
        menu.addItem(pulseItem)

        let warningItem = NSMenuItem(title: "静音讲话警告", action: #selector(toggleMutedSpeechWarning), keyEquivalent: "")
        warningItem.target = self
        warningItem.state = settings.mutedSpeechWarningEnabled ? .on : .off
        menu.addItem(warningItem)

        menu.addItem(NSMenuItem.separator())

        let sizeMenu = NSMenu()
        for size in [72, 96, 120, 144] {
            let item = NSMenuItem(title: "\(size) px", action: #selector(setOverlaySize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = Double(size)
            item.state = Int(settings.overlaySize) == size ? .on : .off
            sizeMenu.addItem(item)
        }

        let sizeItem = NSMenuItem(title: "悬浮窗大小", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func requestPairing() {
        controller.requestPairing()
    }

    @objc private func disconnectAndClearToken() {
        controller.disconnectAndClearToken()
    }

    @objc private func resetOverlayPosition() {
        settings.resetOverlayPosition()
        overlayWindowController?.resetPosition()
    }

    @objc private func togglePulse() {
        settings.pulseEnabled.toggle()
    }

    @objc private func toggleMutedSpeechWarning() {
        settings.mutedSpeechWarningEnabled.toggle()
    }

    @objc private func setOverlaySize(_ sender: NSMenuItem) {
        guard let size = sender.representedObject as? Double else {
            return
        }
        settings.overlaySize = size
        overlayWindowController?.resize()
        updateMenu()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateMicrophoneMonitoring() {
        microphoneMonitor.setEnabled(settings.pulseEnabled || settings.mutedSpeechWarningEnabled)
    }

    private func updateMutedSpeechDetector() {
        mutedSpeechDetector.update(
            level: microphoneMonitor.level,
            shouldDetect: settings.mutedSpeechWarningEnabled && controller.state == .muted && !microphoneMonitor.permissionDenied
        )
    }
}

typealias AnyCancellableBox = AnyCancellable
