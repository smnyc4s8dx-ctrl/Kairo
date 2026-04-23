#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

/// macOS entry point. Owns a single `NSStatusItem` in the menu bar and a
/// lazily-created `NSWindow` that hosts `ContentView`. Single left-click
/// toggles the window; right-click shows Show / Quit menu.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var countdownTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: hide the Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item

        // Observe engine state and keep the menu-bar icon + countdown in sync.
        syncStatusItem()
    }

    /// Bridges Swift Observation → AppKit NSStatusItem. Tracks `phase`,
    /// `endDate`, and `isPaused`; updates icon + countdown title accordingly.
    /// Re-registers on every change (one-shot observation semantics).
    @MainActor
    private func syncStatusItem() {
        let engine = AppServices.shared.engine
        let phase = engine.phase
        let running = engine.endDate != nil && !engine.isPaused
        let paused = engine.isPaused

        statusItem?.button?.image = NSImage(
            systemSymbolName: iconName(for: phase),
            accessibilityDescription: "Kairo"
        )

        if running {
            startCountdownTicker()
        } else if paused {
            stopCountdownTicker()
            statusItem?.button?.title = " " + engine.remaining.mmss
        } else {
            stopCountdownTicker()
            statusItem?.button?.title = ""
        }

        withObservationTracking {
            _ = engine.phase
            _ = engine.endDate
            _ = engine.isPaused
        } onChange: {
            Task { @MainActor [weak self] in
                self?.syncStatusItem()
            }
        }
    }

    /// Polls `engine.remaining` once per second and rewrites the status-item
    /// title. Cancelled when the timer isn't counting down.
    @MainActor
    private func startCountdownTicker() {
        if countdownTask != nil { return }
        countdownTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let engine = AppServices.shared.engine
                if engine.endDate != nil && !engine.isPaused {
                    self.statusItem?.button?.title = " " + engine.remaining.mmss
                } else {
                    self.statusItem?.button?.title = ""
                    break
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @MainActor
    private func stopCountdownTicker() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func iconName(for phase: TimerEngine.Phase) -> String {
        switch phase {
        case .focus: "timer.circle.fill"
        case .shortBreak, .longBreak: "cup.and.saucer.fill"
        case .awaitingEndDecision: "sparkles"
        case .idle: "timer"
        }
    }

    @MainActor
    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            presentContextMenu()
        } else {
            toggleMainWindow()
        }
    }

    @MainActor
    private func presentContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Show Kairo",
            action: #selector(showMainWindow),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Kairo",
            action: #selector(NSApp.terminate(_:)),
            keyEquivalent: "q"
        ))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        // Clear immediately so the next left-click fires the action, not the menu.
        statusItem?.menu = nil
    }

    @MainActor
    @objc private func toggleMainWindow() {
        if let w = mainWindow, w.isVisible {
            w.orderOut(nil)
            return
        }
        showMainWindow()
    }

    @MainActor
    @objc private func showMainWindow() {
        if mainWindow == nil {
            mainWindow = makeMainWindow()
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func makeMainWindow() -> NSWindow {
        let services = AppServices.shared
        let root = ContentView()
            .modelContainer(services.container)
            .environment(services.engine)
            .environment(AppSettings.shared)
            .environment(AmbientSoundService.shared)
            .environment(ToastCenter.shared)

        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.setContentSize(NSSize(width: 400, height: 720))
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
#endif
