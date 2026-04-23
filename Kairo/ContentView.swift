import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(AmbientSoundService.self) private var sounds

    @State private var showSettings = false
    @State private var showAddTask = false
    @State private var showCompleted = false
    @State private var hasInitialized = false

    var body: some View {
        rootLayout
            .overlay { ToastBanner() }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    #if os(macOS)
                    .frame(minWidth: 440, minHeight: 520)
                    #endif
            }
            .sheet(isPresented: $showAddTask) {
                AddEditTaskSheet()
                    #if os(macOS)
                    .frame(minWidth: 460, minHeight: 580)
                    #endif
            }
            .sheet(isPresented: $showCompleted) {
                CompletedTasksSheet()
                    #if os(macOS)
                    .frame(minWidth: 440, minHeight: 500)
                    #endif
            }
            .sheet(isPresented: Binding(
                get: { engine.phase == .awaitingEndDecision },
                set: { _ in }
            )) {
                WaveEndSheet()
                    #if os(macOS)
                    .frame(minWidth: 380, minHeight: 340)
                    #endif
            }
            .task { await performInitialSetup() }
            .onChange(of: engine.phase) { _, new in
                syncLiveAndSound(for: new)
            }
    }

    @ViewBuilder
    private var rootLayout: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadLayout
        } else {
            phoneLayout
        }
        #else
        phoneLayout
        #endif
    }

    private var phoneLayout: some View {
        VStack(spacing: 0) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        TimerView()
                            .padding(.top, 8)
                        tasksHeader
                        TaskListView()
                            .frame(minHeight: 320)
                    }
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("Kairo")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { iosBottomBar }
                #endif
            }

            #if os(macOS)
            macBottomBar
            #endif
        }
    }

    #if os(iOS)
    private var iPadLayout: some View {
        NavigationSplitView {
            TaskListView()
                .navigationTitle("Tasks")
                .toolbar { iosBottomBar }
        } detail: {
            TimerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    #endif

    private var tasksHeader: some View {
        HStack {
            Text("Tasks")
                .font(.title3.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Bottom bar

    #if os(iOS)
    @ToolbarContentBuilder
    private var iosBottomBar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button { showSettings = true } label: {
                Label("Settings", systemImage: "gearshape")
            }
            Button { showCompleted = true } label: {
                Label("Completed", systemImage: "checkmark.circle")
            }
            Spacer()
            Button { showAddTask = true } label: {
                Label("New Task", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.accentColor)
        }
    }
    #endif

    #if os(macOS)
    private var macBottomBar: some View {
        HStack(spacing: 10) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button { showCompleted = true } label: {
                Image(systemName: "checkmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Completed tasks")

            Spacer()

            Button { showAddTask = true } label: {
                Label("New Task", systemImage: "plus")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .help("Add a new task")
        }
        .padding(12)
        .background(.bar)
    }
    #endif

    // MARK: - Lifecycle + phase sync

    private func performInitialSetup() async {
        guard !hasInitialized else { return }
        hasInitialized = true
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
}
