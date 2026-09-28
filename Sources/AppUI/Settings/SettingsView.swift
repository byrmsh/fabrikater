import AppModel
import SwiftUI

/// fabrikater ▸ Settings… (⌘,): the host, the composer's send key, notifications and text sizes (docs/design.md,
/// "Settings"). Every change is saved as it is made.
public struct SettingsView: View {
    let preferences: PreferencesStore

    public init(preferences: PreferencesStore) {
        self.preferences = preferences
    }

    public var body: some View {
        Form {
            Section {
                TextField("Host", text: host, prompt: Text(preferences.hostPlaceholder))
                    .autocorrectionDisabled()
                    .fontDesign(.monospaced)
            } header: {
                Text("Connection")
            } footer: {
                Text(preferences.hostNotice)
                    .foregroundStyle(preferences.hostIsInvalid ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
            }
            Section {
                Picker("Send with", selection: binding(\.sendKey)) {
                    ForEach(SendKey.allCases, id: \.self) { key in
                        Text(key.title).tag(key)
                    }
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
            } header: {
                Text("Composer")
            } footer: {
                Text(preferences.preferences.sendKey.newlineHint)
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("When a pane needs input", isOn: binding(\.notifiesBlocked))
                Toggle("When an agent finishes its turn", isOn: binding(\.notifiesFinished))
                Toggle("Play a sound", isOn: binding(\.playsSound))
            } header: {
                Text("Notifications")
            } footer: {
                Text("A workspace's context menu turns its notifications off.")
                    .foregroundStyle(.secondary)
            }
            Section {
                sizeStepper("Conversation", binding(\.conversationTextSize))
                sizeStepper("Terminal", binding(\.terminalTextSize))
            } header: {
                Text("Text Size")
            } footer: {
                Text("View ▸ Bigger and Smaller change both in the front window.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sizeStepper(_ title: String, _ size: Binding<Int>) -> some View {
        Stepper(value: size, in: Preferences.textSizes) {
            LabeledContent(title, value: Preferences.pointsTitle(size.wrappedValue))
        }
    }

    private var host: Binding<String> {
        Binding {
            preferences.hostText
        } set: { text in
            preferences.setHostText(text)
        }
    }

    private func binding<Value: Equatable>(_ field: any WritableKeyPath<Preferences, Value> & Sendable) -> Binding<
        Value
    > {
        Binding {
            preferences.preferences[keyPath: field]
        } set: { value in
            preferences.set(field, to: value)
        }
    }
}
