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
                HStack {
                    TextField("Host", text: host, prompt: Text(preferences.hostPlaceholder))
                        .autocorrectionDisabled()
                        .onSubmit { preferences.connect() }
                    Button(PreferencesStore.connectTitle) { preferences.connect() }
                        .disabled(!preferences.canConnect)
                }
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
                Toggle("Show Needs You in the menu bar", isOn: binding(\.showsMenuBarItem))
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("A bell counts the panes waiting on you; its menu opens one.")
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
        .announcing(preferences.hostIsInvalid ? preferences.hostNotice : nil)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sizeStepper(_ title: String, _ size: Binding<Int>) -> some View {
        Stepper(value: size, in: Preferences.textSizes) {
            LabeledContent(title, value: Preferences.pointsTitle(size.wrappedValue))
        }
        // The stepper itself reads as its row's name and size, and says the new size as it steps.
        .accessibilityLabel("\(title) Text Size")
        .accessibilityValue(Preferences.pointsTitle(size.wrappedValue))
    }

    /// A preference the form edits; the key path is captured by the binding's closures, so it must be `Sendable`.
    private typealias Field<Value> = any WritableKeyPath<Preferences, Value> & Sendable

    private var host: Binding<String> {
        Binding {
            preferences.hostText
        } set: { text in
            preferences.setHostText(text)
        }
    }

    private func binding<Value: Equatable>(_ field: Field<Value>) -> Binding<Value> {
        Binding {
            preferences.preferences[keyPath: field]
        } set: { value in
            preferences.set(field, to: value)
        }
    }
}
