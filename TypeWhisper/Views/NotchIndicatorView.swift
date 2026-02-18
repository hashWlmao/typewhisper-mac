import SwiftUI

/// Notch-extending indicator that visually expands the MacBook notch area.
/// Three-zone layout: left ear (indicator) | center (notch spacer) | right ear (timer).
/// Expands wider and downward to show streaming partial text.
/// Blue glow emanates from the notch shape, reacting to audio level.
struct NotchIndicatorView: View {
    @ObservedObject private var viewModel = DictationViewModel.shared
    @ObservedObject var geometry: NotchGeometry
    @State private var textExpanded = false
    @State private var dotPulse = false

    private let extensionWidth: CGFloat = 60

    private var closedWidth: CGFloat {
        geometry.hasNotch ? geometry.notchWidth + 2 * extensionWidth : 200
    }

    private var currentWidth: CGFloat {
        textExpanded ? max(closedWidth, 400) : closedWidth
    }

    // MARK: - Audio-reactive glow

    private var glowOpacity: Double {
        guard viewModel.state == .recording else { return 0 }
        return max(0.25, min(Double(viewModel.audioLevel) * 2.5, 0.9))
    }

    private var glowRadius: CGFloat {
        guard viewModel.state == .recording else { return 0 }
        return max(6, CGFloat(viewModel.audioLevel) * 25 + 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Three-zone status bar
            statusBar
                .frame(height: geometry.notchHeight)

            // Expandable partial text area
            if viewModel.state == .recording {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        Text(viewModel.partialText)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 34)
                            .padding(.top, 14)
                            .padding(.bottom, 16)
                            .id("bottom")
                    }
                    .frame(height: textExpanded ? 80 : 0)
                    .clipped()
                    .onChange(of: viewModel.partialText) {
                        if !viewModel.partialText.isEmpty, !textExpanded {
                            withAnimation(.easeOut(duration: 0.25)) {
                                textExpanded = true
                            }
                        }
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .transaction { $0.disablesAnimations = true }
            }
        }
        .frame(width: currentWidth)
        .background(.black)
        .clipShape(NotchShape(
            topCornerRadius: textExpanded ? 19 : 6,
            bottomCornerRadius: textExpanded ? 24 : 14
        ))
        // Blue glow that reacts to audio level
        .shadow(color: Color(red: 0.3, green: 0.5, blue: 1.0).opacity(glowOpacity), radius: glowRadius)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: textExpanded)
        .animation(.easeInOut(duration: 0.2), value: viewModel.state)
        .animation(.easeOut(duration: 0.08), value: viewModel.audioLevel)
        .onChange(of: viewModel.state) {
            if viewModel.state == .recording {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    dotPulse = true
                }
            } else {
                dotPulse = false
                textExpanded = false
            }
        }
    }

    // MARK: - Status bar (three-zone layout)

    @ViewBuilder
    private var statusBar: some View {
        HStack(spacing: 0) {
            leftContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 34)

            // Center: notch spacer (invisible black, matches hardware notch)
            if geometry.hasNotch {
                Color.clear
                    .frame(width: geometry.notchWidth)
            }

            rightContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 34)
        }
    }

    @ViewBuilder
    private var leftContent: some View {
        switch viewModel.state {
        case .idle:
            Color.clear
        case .recording:
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
                .scaleEffect(1.0 + CGFloat(viewModel.audioLevel) * 0.8)
                .shadow(color: .yellow.opacity(dotPulse ? 0.8 : 0.2), radius: dotPulse ? 6 : 2)
        case .processing:
            ProgressView()
                .controlSize(.mini)
                .tint(.white)
        case .inserting:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 11))
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.system(size: 11))
        }
    }

    @ViewBuilder
    private var rightContent: some View {
        switch viewModel.state {
        case .recording:
            Text(formatDuration(viewModel.recordingDuration))
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.6))
        default:
            Color.clear
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
