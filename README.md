# Kairo

A privacy-first Pomodoro and to-do app for iOS, iPadOS, macOS, and visionOS. Built with Swift 6 and SwiftUI; zero third-party dependencies in the shipped binary.

> **Status:** No longer actively developed by the original author. Released as MIT-licensed open source. Pull requests are welcome but review is not guaranteed. Forks encouraged.

## What it is

- A Pomodoro timer with proper state machine (focus → optional decision → short or long break → next focus), auto-start toggles, and live activities on iOS.
- A to-do list with priority, due dates, recurrence (daily / weekdays / weekends / weekly / monthly), one level of subtasks, and undo via toast.
- A macOS menu-bar accessory app — no Dock icon. Left-click the status item to toggle the window; right-click for Show / Quit.
- Ambient background sounds (white, pink, brown noise) generated procedurally — no audio files shipped.

## Privacy promise

- No analytics. No telemetry. No tracking. No advertising. None.
- All data lives on the device. CloudKit sync is opt-in (see [Setup](docs/SETUP.md) — the iCloud container is intentionally empty in this repo; configure your own to enable sync).
- No third-party SDKs in the shipped binary. Apple frameworks only (SwiftUI, SwiftData, AVFoundation, UserNotifications, ActivityKit, AppKit).

## Build

See [docs/SETUP.md](docs/SETUP.md). Briefly:

1. Clone.
2. Open `Kairo/Kairo.xcodeproj` in Xcode 26 or later.
3. Set your own development team in target signing.
4. (Optional) Change the bundle identifier to something under your own reverse-DNS.
5. Build and run on simulator or device.

## Architecture at a glance

- **Pattern**: MV (Model-View). SwiftUI views read SwiftData via `@Query`; shared mutable state lives in `@Observable @MainActor` singletons. No view models, no MVVM, no TCA, no Redux.
- **Persistence**: SwiftData. The `ModelContainer` is built in `Services/AppServices.swift` and shared across iOS and macOS surfaces.
- **Concurrency**: Swift 6 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — types are `MainActor`-isolated by default unless explicitly marked otherwise.
- **Testing**: `swift test` against the `KairoCore` SPM target exercises model and service logic without a `ModelContainer`. UI testing via XcodeBuildMCP (see [docs/SETUP.md](docs/SETUP.md)).

Full architectural overview: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Documentation

- [docs/SETUP.md](docs/SETUP.md) — clone, sign, build, run; CloudKit setup notes
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — code layout, modules, invariants
- [docs/COMPETITIVE_ANALYSIS.md](docs/COMPETITIVE_ANALYSIS.md) — historical strategic doc surveying similar OSS apps and identifying patterns; useful as design context for contributors
- [docs/FEATURE_BACKLOG.md](docs/FEATURE_BACKLOG.md) — feature ideas with file-level implementation plans; a starting point for contributors
- [CONVENTIONS.md](CONVENTIONS.md) — project conventions (privacy, dependencies, code style, comments)
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to contribute
- [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) — Contributor Covenant 2.1

## License

[MIT](LICENSE). Use, fork, ship, sell — anything the license allows. Attribution requested but not demanded beyond the license text.

## Why this exists publicly

Kairo started as a private indie product. It is no longer being developed commercially. Rather than letting the code rot privately, it ships here so the patterns (privacy-first, zero-deps, native multi-platform Swift/SwiftUI architecture) are available for anyone who wants to study them, fork them, or take the project further.
