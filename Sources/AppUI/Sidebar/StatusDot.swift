import AppModel
import FabrikaterCore
import SwiftUI

/// An 8 pt dot for an agent status: working pulses, blocked asks for attention, done is unseen. With Differentiate
/// Without Color on, each status gets its own shape, so the colour is never the only sign.
struct StatusDot: View {
    let status: AgentStatus
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiatesWithoutColor

    var body: some View {
        Group {
            if differentiatesWithoutColor {
                Image(systemName: shapeSymbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 10, height: 10)
            } else {
                dot
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel(status.title)
    }

    @ViewBuilder
    private var dot: some View {
        if status == .working {
            Circle()
                .fill(color)
                .phaseAnimator([1.0, 0.35]) { circle, opacity in
                    circle.opacity(opacity)
                } animation: { _ in
                    .easeInOut(duration: 0.8)
                }
        } else {
            Circle()
                .fill(color)
        }
    }

    private var color: Color {
        switch status {
        case .working: .accentColor
        case .blocked: .orange
        case .done: .green
        case .idle: .secondary
        case .unknown: .clear
        }
    }

    private var shapeSymbol: String {
        switch status {
        case .working: "ellipsis.circle.fill"
        case .blocked: "exclamationmark.circle.fill"
        case .done: "checkmark.circle.fill"
        case .idle: "circle"
        case .unknown: "questionmark.circle"
        }
    }
}
