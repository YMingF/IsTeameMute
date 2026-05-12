import Combine
import SwiftUI
import TeamsMuteOverlayCore

struct OverlayButtonView: View {
    @ObservedObject var controller: TeamsOverlayController
    @ObservedObject var settings: AppSettings
    @ObservedObject var microphoneMonitor: MicrophoneLevelMonitor
    @ObservedObject var mutedSpeechDetector: MutedSpeechDetector
    var shouldSuppressToggle: () -> Bool = { false }
    @State private var warningPulse = false
    @State private var warningPulseCancellable: AnyCancellable?
    @State private var shouldSuppressNextToggle = false

    var body: some View {
        Button {
            guard !consumeToggleSuppression() else {
                return
            }
            controller.toggleMute()
        } label: {
            ZStack {
                Circle()
                    .fill(statusTint)

                if showsWaterMeter {
                    VStack {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(waterTint)
                            .frame(height: waterHeight)
                    }
                    .clipShape(Circle())
                    .animation(.easeOut(duration: 0.12), value: waterHeight)
                }

                VStack(spacing: verticalSpacing) {
                    if mutedSpeechDetector.isWarningActive {
                        Text("SPEAKING")
                            .font(.system(size: warningSize, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .foregroundStyle(.white)
                    }

                    Text(controller.state.shortLabel)
                        .font(.system(size: labelSize, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(.white)

                    if showsDetail {
                        Text(detailLabel)
                            .font(.system(size: detailSize, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                            .foregroundStyle(.white.opacity(0.86))
                    }
                }
            }
            .frame(width: settings.overlaySize, height: settings.overlaySize)
            .contentShape(Circle())
            .scaleEffect(warningScale)
        }
        .buttonStyle(.plain)
        .disabled(!controller.state.canToggleMute)
        .frame(width: settings.overlaySize * 1.28, height: settings.overlaySize * 1.28)
        .help(controller.state.detail)
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { _ in
                    shouldSuppressNextToggle = true
                }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        shouldSuppressNextToggle = false
                    }
                }
        )
        .onChange(of: mutedSpeechDetector.isWarningActive) { isActive in
            if isActive {
                startWarningPulse()
            } else {
                stopWarningPulse()
            }
        }
        .onAppear {
            if mutedSpeechDetector.isWarningActive {
                startWarningPulse()
            } else {
                stopWarningPulse()
            }
        }
        .onDisappear {
            stopWarningPulse()
        }
    }

    private var labelSize: Double {
        max(14, settings.overlaySize * (mutedSpeechDetector.isWarningActive ? 0.18 : 0.21))
    }

    private var detailSize: Double {
        max(8, settings.overlaySize * (mutedSpeechDetector.isWarningActive ? 0.08 : 0.09))
    }

    private var warningSize: Double {
        max(9, settings.overlaySize * 0.10)
    }

    private var verticalSpacing: Double {
        max(3, settings.overlaySize * 0.035)
    }

    private var showsDetail: Bool {
        settings.overlaySize >= 88 && controller.state.canToggleMute
    }

    private var showsWaterMeter: Bool {
        controller.state == .unmuted
    }

    private var waterHeight: Double {
        settings.overlaySize * Double(min(1, max(0, microphoneMonitor.level)))
    }

    private var waterTint: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.52, green: 1.00, blue: 0.72).opacity(0.84),
                Color(red: 0.10, green: 0.84, blue: 0.44).opacity(0.70)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var detailLabel: String {
        if mutedSpeechDetector.isWarningActive {
            return "MIC IS OFF"
        }

        switch controller.state {
        case .unmuted:
            return "TEAMS MIC"
        case .muted:
            return "CLICK"
        default:
            return controller.state.detail
        }
    }

    private var statusColor: Color {
        switch controller.state {
        case .muted:
            return Color(red: 0.92, green: 0.08, blue: 0.12)
        case .unmuted:
            return Color(red: 0.05, green: 0.58, blue: 0.26)
        case .syncing:
            return Color(red: 0.12, green: 0.40, blue: 0.86)
        case .error:
            return Color(red: 0.86, green: 0.26, blue: 0.12)
        case .pairingRequired:
            return Color(red: 0.18, green: 0.40, blue: 0.72)
        default:
            return Color(red: 0.34, green: 0.36, blue: 0.40)
        }
    }

    private var statusTint: some ShapeStyle {
        LinearGradient(
            colors: [
                statusColor.opacity(controller.state.canToggleMute ? 0.74 : 0.50),
                statusColor.opacity(controller.state.canToggleMute ? 0.52 : 0.36)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var warningScale: Double {
        mutedSpeechDetector.isWarningActive && warningPulse ? 1.12 : 1.0
    }

    private func consumeToggleSuppression() -> Bool {
        let shouldSuppress = shouldSuppressNextToggle || shouldSuppressToggle()
        shouldSuppressNextToggle = false
        return shouldSuppress
    }

    private func startWarningPulse() {
        warningPulseCancellable?.cancel()
        withAnimation(.easeInOut(duration: 0.55)) {
            warningPulse = true
        }
        warningPulseCancellable = Timer.publish(every: 0.55, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                guard mutedSpeechDetector.isWarningActive else {
                    stopWarningPulse()
                    return
                }
                withAnimation(.easeInOut(duration: 0.55)) {
                    warningPulse.toggle()
                }
            }
    }

    private func stopWarningPulse() {
        warningPulseCancellable?.cancel()
        warningPulseCancellable = nil
        withAnimation(.easeOut(duration: 0.12)) {
            warningPulse = false
        }
    }

}
