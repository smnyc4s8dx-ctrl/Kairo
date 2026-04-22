import SwiftUI
import SwiftData

@main
struct KairoApp: App {
    private let container: ModelContainer
    @State private var engine: TimerEngine
    private let settings = AppSettings.shared
    private let sounds = AmbientSoundService.shared

    init() {
        let container = Self.buildContainer()
        self.container = container
        self._engine = State(initialValue: TimerEngine(modelContext: container.mainContext))
    }

    var body: some Scene {
        #if os(macOS)
        MenuBarExtra {
            MenuBarView()
                .modelContainer(container)
                .environment(engine)
                .environment(settings)
                .environment(sounds)
                .task { await onAppLaunch() }
                .onChange(of: engine.phase) { _, new in
                    syncLiveAndSound(for: new)
                }
        } label: {
            MenuBarLabel()
                .environment(engine)
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environment(engine)
                .environment(settings)
                .environment(sounds)
                .task { await onAppLaunch() }
                .onChange(of: engine.phase) { _, new in
                    syncLiveAndSound(for: new)
                }
        }
        #endif
    }

    private func onAppLaunch() async {
        if settings.notificationsEnabled {
            _ = await NotificationService.shared.requestAuthorization()
        }
        sounds.volume = Float(settings.ambientSoundVolume)
    }

    private func syncLiveAndSound(for phase: TimerEngine.Phase) {
        // Ambient sounds: on during focus, off otherwise.
        switch phase {
        case .focus:
            if settings.ambientSound != .none, sounds.current != settings.ambientSound {
                sounds.play(settings.ambientSound)
            }
        default:
            sounds.stop()
        }

        // Live Activity (iOS only — no-op shim on macOS).
        switch phase {
        case .focus:
            if let end = engine.endDate {
                LiveActivityService.shared.start(
                    phaseLabel: "Focus",
                    endDate: end,
                    activeTask: engine.activeTask?.title
                )
            }
        case .shortBreak, .longBreak:
            if let end = engine.endDate {
                LiveActivityService.shared.update(
                    phaseLabel: phase == .longBreak ? "Long break" : "Short break",
                    endDate: end,
                    activeTask: nil,
                    isPaused: engine.isPaused
                )
            }
        case .idle, .awaitingEndDecision:
            LiveActivityService.shared.endCurrent()
        }
    }

    private static func buildContainer() -> ModelContainer {
        let schema = Schema([TaskItem.self, Wave.self])
        let config: ModelConfiguration
        if AppSettings.shared.iCloudSyncEnabled {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
        } else {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fallback: rebuild in-memory so a corrupt store doesn't brick the app.
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [memory]))
                ?? { fatalError("ModelContainer init failed: \(error)") }()
        }
    }
}
