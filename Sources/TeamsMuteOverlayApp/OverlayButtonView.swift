import SwiftUI
import TeamsMuteOverlayCore

struct OverlayButtonView: View {
    @ObservedObject var controller: TeamsOverlayController
    @ObservedObject var settings: AppSettings
    @ObservedObject var microphoneMonitor: MicrophoneLevelMonitor
    @ObservedObject var mutedSpeechDetector: MutedSpeechDetector
    @State private var warningPulse = false

    var body: some View {
        Button {
            controller.toggleMute()
        } label: {
            VStack(spacing: verticalSpacing) {
                if mutedSpeechDetector.isWarningActive {
                    Text("SPEAKING")
                        .font(.system(size: warningSize, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.32), radius: 1.5, x: 0, y: 1)
                }

                Text(controller.state.shortLabel)
                    .font(.system(size: labelSize, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.28), radius: 1.5, x: 0, y: 1)

                if showsDetail {
                    Text(detailLabel)
                        .font(.system(size: detailSize, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(.white.opacity(0.86))
                        .shadow(color: .black.opacity(0.20), radius: 1, x: 0, y: 1)
                }
            }
            .frame(width: settings.overlaySize, height: settings.overlaySize)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(statusTint, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(glassHighlight)
            .overlay(statusBorder)
            .overlay(pulseOverlay)
            .overlay(mutedSpeechWarningOverlay)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(warningScale)
            .animation(
                mutedSpeechDetector.isWarningActive
                    ? .easeInOut(duration: 0.62).repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.16),
                value: warningPulse
            )
        }
        .buttonStyle(.plain)
        .disabled(!controller.state.canToggleMute)
        .frame(width: settings.overlaySize * 1.28, height: settings.overlaySize * 1.28)
        .help(controller.state.detail)
        .onChange(of: mutedSpeechDetector.isWarningActive) { isActive in
            if isActive {
                warningPulse = true
            } else {
                withAnimation(.easeOut(duration: 0.12)) {
                    warningPulse = false
                }
            }
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

    private var cornerRadius: Double {
        min(24, max(16, settings.overlaySize * 0.20))
    }

    private var showsDetail: Bool {
        settings.overlaySize >= 88 && controller.state.canToggleMute
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

    private var glassHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.34),
                        .white.opacity(0.10),
                        .white.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
    }

    private var statusBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.58),
                        .white.opacity(0.16),
                        statusColor.opacity(0.42)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    @ViewBuilder
    private var pulseOverlay: some View {
        if controller.state == .unmuted && settings.pulseEnabled && !microphoneMonitor.permissionDenied {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    .white.opacity(0.22 + Double(microphoneMonitor.level) * 0.50),
                    lineWidth: 2.5 + CGFloat(microphoneMonitor.level) * 5.5
                )
                .animation(.easeOut(duration: 0.12), value: microphoneMonitor.level)
        }
    }

    @ViewBuilder
    private var mutedSpeechWarningOverlay: some View {
        if mutedSpeechDetector.isWarningActive {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.96),
                            Color(red: 1.0, green: 0.30, blue: 0.33).opacity(0.90),
                            Color.white.opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: max(3, settings.overlaySize * 0.045)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color(red: 0.96, green: 0.10, blue: 0.14).opacity(0.58), lineWidth: max(9, settings.overlaySize * 0.11))
                        .blur(radius: 3.5)
                )
                .animation(.easeInOut(duration: 0.18), value: mutedSpeechDetector.isWarningActive)
        }
    }

    private var shadowColor: Color {
        switch controller.state {
        case .muted:
            return mutedSpeechDetector.isWarningActive ? .red.opacity(0.50) : .red.opacity(0.30)
        case .unmuted:
            return .green.opacity(0.26)
        case .syncing:
            return .blue.opacity(0.24)
        default:
            return .black.opacity(0.24)
        }
    }

    private var shadowRadius: Double {
        mutedSpeechDetector.isWarningActive ? 20 : (controller.state.canToggleMute ? 13 : 9)
    }

    private var shadowY: Double {
        controller.state.canToggleMute ? 6 : 4
    }

    private var warningScale: Double {
        mutedSpeechDetector.isWarningActive && warningPulse ? 1.12 : 1.0
    }

}
