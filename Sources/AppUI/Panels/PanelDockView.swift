import AppModel
import SwiftUI

/// The panels one dock shows, top to bottom, each under its header. Above the conversation each is kept short; in a
/// column the last one takes the room left.
struct PanelDockView: View {
    let dock: PanelDock
    let model: any PaneDetailModel

    /// How tall a panel above the conversation may grow, so the conversation keeps its room.
    private static let topPanelHeight = 220.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(model.detail.panels(in: dock).enumerated()), id: \.element) { index, panel in
                if index > 0 {
                    Divider()
                }
                VStack(alignment: .leading, spacing: 0) {
                    PanelHeader(panel: panel, detail: model.detail.headerDetail(of: panel), model: model)
                    InfoPanelView(panel: panel, model: model)
                        .frame(maxHeight: dock == .top ? Self.topPanelHeight : .infinity, alignment: .top)
                        .fixedSize(horizontal: false, vertical: panel != .changes)
                }
                // A group VoiceOver names by the panel, so its rotor and ⌃⌥⇧↓ step into one panel at a time.
                .accessibilityElement(children: .contain)
                .accessibilityLabel(panel.title)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: dock == .top ? nil : .infinity, alignment: .top)
    }
}
