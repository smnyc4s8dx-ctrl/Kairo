import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(TimerEngine.self) private var engine

    @State private var showSettings = false
    @State private var showAddTask = false
    @State private var showCompleted = false

    var body: some View {
        #if os(iOS)
        iOSLayout
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showAddTask) { AddEditTaskSheet() }
            .sheet(isPresented: $showCompleted) { CompletedTasksSheet() }
            .sheet(isPresented: Binding(
                get: { engine.phase == .awaitingEndDecision },
                set: { _ in }
            )) { WaveEndSheet() }
        #else
        EmptyView()
        #endif
    }

    #if os(iOS)
    @ViewBuilder
    private var iOSLayout: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    private var iPhoneLayout: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    TimerView()
                        .padding(.top, 8)

                    tasksHeader

                    TaskListView()
                        .frame(minHeight: 320)
                }
                .padding(.bottom, 72) // breathing room above floating bottom bar
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Kairo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { bottomBar }
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            TaskListView()
                .navigationTitle("Tasks")
                .toolbar { bottomBar }
        } detail: {
            TimerView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var tasksHeader: some View {
        HStack {
            Text("Tasks")
                .font(.title3.weight(.semibold))
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    @ToolbarContentBuilder
    private var bottomBar: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Button { showSettings = true } label: {
                Label("Settings", systemImage: "gearshape")
            }

            Button { showCompleted = true } label: {
                Label("Completed", systemImage: "checkmark.circle")
            }

            Spacer()

            Button {
                showAddTask = true
            } label: {
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
}
