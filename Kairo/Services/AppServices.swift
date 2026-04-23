import Foundation
import SwiftData

/// Shared service bag. Holds the `ModelContainer` and long-lived `TimerEngine`
/// so both SwiftUI (iOS) and AppKit-hosted (macOS) entry points can pull from
/// the same source.
@MainActor
final class AppServices {
    static let shared = AppServices()

    let container: ModelContainer
    let engine: TimerEngine

    private init() {
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

        let built: ModelContainer
        do {
            built = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Last-resort fallback: corrupt store shouldn't brick the app.
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            built = (try? ModelContainer(for: schema, configurations: [memory]))
                ?? { fatalError("ModelContainer init failed: \(error)") }()
        }
        self.container = built
        self.engine = TimerEngine(modelContext: built.mainContext)
    }
}
