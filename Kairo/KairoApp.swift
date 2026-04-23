import SwiftUI
import SwiftData

@main
struct KairoApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        // Real UI lives in an NSWindow managed by `AppDelegate`. Settings scene
        // (opened via ⌘,) presents the full SettingsView so the standard
        // macOS shortcut still works.
        Settings {
            SettingsView()
                .modelContainer(AppServices.shared.container)
                .environment(AppServices.shared.engine)
                .environment(AppSettings.shared)
                .environment(AmbientSoundService.shared)
                .environment(ToastCenter.shared)
                .frame(minWidth: 440, minHeight: 520)
        }
        #else
        WindowGroup {
            ContentView()
                .modelContainer(AppServices.shared.container)
                .environment(AppServices.shared.engine)
                .environment(AppSettings.shared)
                .environment(AmbientSoundService.shared)
                .environment(ToastCenter.shared)
        }
        #endif
    }
}
