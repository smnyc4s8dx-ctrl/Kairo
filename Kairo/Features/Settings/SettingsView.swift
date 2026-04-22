import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AmbientSoundService.self) private var sounds
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var s = settings

        NavigationStack {
            Form {
                Section("Durations") {
                    Stepper("Focus — \(s.focusDurationMinutes) min",
                            value: $s.focusDurationMinutes, in: 5...90, step: 1)
                    Stepper("Short break — \(s.shortBreakMinutes) min",
                            value: $s.shortBreakMinutes, in: 1...30, step: 1)
                    Stepper("Long break — \(s.longBreakMinutes) min",
                            value: $s.longBreakMinutes, in: 5...60, step: 1)
                    Stepper("Waves until long break — \(s.wavesUntilLongBreak)",
                            value: $s.wavesUntilLongBreak, in: 2...12, step: 1)
                }

                Section("Flow") {
                    Toggle("Auto-start breaks", isOn: $s.autoStartBreak)
                    Toggle("Auto-start next wave", isOn: $s.autoStartNextWave)
                }

                Section("Notifications") {
                    Toggle("Alert at wave & break end", isOn: $s.notificationsEnabled)
                        .onChange(of: s.notificationsEnabled) { _, newVal in
                            if newVal {
                                Task { await NotificationService.shared.requestAuthorization() }
                            }
                        }
                }

                Section {
                    Picker("Sound", selection: Binding(
                        get: { s.ambientSound },
                        set: { s.ambientSound = $0; applySoundChange() }
                    )) {
                        ForEach(AmbientSound.allCases) { sound in
                            Label(sound.label, systemImage: sound.symbol).tag(sound)
                        }
                    }
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: Binding(
                            get: { s.ambientSoundVolume },
                            set: {
                                s.ambientSoundVolume = $0
                                sounds.volume = Float($0)
                            }
                        ), in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                } header: {
                    Text("Ambient focus sound")
                } footer: {
                    Text("Procedurally generated — nothing streams, nothing downloads.")
                }

                Section {
                    Toggle("Sync across devices (iCloud)", isOn: $s.iCloudSyncEnabled)
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Tasks and wave history sync through your private iCloud container. Restart the app after changing this setting.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func applySoundChange() {
        sounds.volume = Float(settings.ambientSoundVolume)
        sounds.play(settings.ambientSound)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
