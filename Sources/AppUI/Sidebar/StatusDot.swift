import AppModel
import FabrikaterCore
import SwiftUI

/// An 8 pt dot for an agent status: working pulses, blocked asks for attention, done is unseen.
struct StatusDot: View {
    let status: AgentStatus

    var body: some View {
        dot
            .frame(width: 8, height: 8)
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
}
