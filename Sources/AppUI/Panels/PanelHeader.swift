import AppModel
import SwiftUI

/// A panel's title bar: its name, a short detail such as the plan's progress, and a menu to hide or move it, which a
/// right-click on the bar also opens.
struct PanelHeader: View {
    let panel: InfoPanel
    let detail: String?
    let model: any PaneDetailModel

    var body: some View {
        HStack(spacing: 6) {
            Text(panel.title)
                .scaledFont(.callout)
                .fontWeight(.semibold)
            if let detail {
                Text(detail)
                    .scaledFont(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel(panel.menuTitle)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .controlSize(.small)
            .help(panel.menuTitle)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu { menuItems }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var menuItems: some View {
        Button(panel.hideTitle) { model.perform(.togglePanel(panel)) }
        Divider()
        PanelMenuItems(
            panel: panel, isEnabled: { model.isEnabled($0) }, isChecked: { model.panels.isChecked($0) == true },
            perform: { model.perform($0) })
    }
}
