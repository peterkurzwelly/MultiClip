import SwiftUI

struct PreferencesView: View {
    @State private var settings = Settings.shared

    var body: some View {
        Form {
            Section("History") {
                HStack {
                    Text("Max items")
                    Spacer()
                    Picker("", selection: $settings.historySize) {
                        Text("10").tag(10)
                        Text("25").tag(25)
                        Text("50").tag(50)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }

                Picker("Auto-clear after", selection: $settings.autoClearInterval) {
                    ForEach(Settings.autoClearOptions, id: \.1) { label, value in
                        Text(label).tag(value)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Play sound on paste", isOn: $settings.pasteSoundEnabled)
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }

            Section("Shortcut") {
                HStack {
                    Text("Open clipboard history")
                    Spacer()
                    Text("⌥⌘V")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.controlBackgroundColor))
                        )
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Spacer()
                    Text("MultiClip v0.1.0")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 320)
    }
}
