# Contributing to Kairo

Thanks for considering a contribution.

## Project status

The original author is no longer actively developing Kairo. Pull requests are welcome, but **review is not guaranteed and may be slow or absent**. If you need a feature shipped on a timeline, fork — the MIT license permits everything you need.

## What kinds of contributions fit

Good fits:
- Bug fixes (with a brief reproduction case in the PR description)
- Features from [docs/FEATURE_BACKLOG.md](docs/FEATURE_BACKLOG.md) — most have file-level implementation plans
- Accessibility improvements (VoiceOver, Dynamic Type, Reduce Motion, Increased Contrast)
- Documentation fixes
- New tests against `KairoCore`

Poor fits — likely to be declined:
- Adding any third-party dependency to the shipped binary (test-only SPM deps in `KairoCore` are fine)
- Telemetry, analytics, crash reporters that phone home
- Paid SaaS integrations
- Feature creep that conflicts with the stated principles in [CONVENTIONS.md](CONVENTIONS.md)
- Architectural rewrites (MVVM, TCA, Redux migrations) — the MV pattern is intentional

## Before you submit

1. **Read [CONVENTIONS.md](CONVENTIONS.md).** The privacy / zero-deps / MV constraints are project axioms.
2. **Match existing patterns.** Look at how a similar feature is structured before inventing a new style.
3. **Build cleanly.** Resolve all warnings. The project leans toward "warnings as errors when feasible."
4. **Add tests** for any non-trivial logic. Pure-logic tests live in `Kairo/Tests/KairoCoreTests/` and run via `swift test` from the `Kairo/` directory.
5. **Accessibility** — any new view should respect Dynamic Type and have meaningful VoiceOver labels.

## Code style

- Follow the conventions in existing source files — naming, file layout, comment style.
- See [CONVENTIONS.md § Comments](CONVENTIONS.md#comments) for the specific guidance on `///` vs `//` and what comments should and should not say.
- No boilerplate file headers (no `//  Created by …` blocks). The project has been clean of these from the start.

## Submitting a PR

1. Fork the repo.
2. Create a feature branch (`git checkout -b feature/your-thing`).
3. Make focused commits — one logical change per commit, present-tense imperative messages ("Add stats heatmap view", not "Added stats heatmap view").
4. Open a PR with:
   - What changed and why
   - How to verify (manual steps if UI; `swift test` invocation if logic)
   - Screenshots / screen recordings for any UI change
5. Be patient. The author may not respond.

## Licensing of contributions

By submitting a pull request, you agree that your contribution is licensed under the same MIT license as the project. Don't include code from incompatible licenses (GPL, AGPL, proprietary, etc.).

## Building and testing

See [docs/SETUP.md](docs/SETUP.md) for clone / sign / build instructions.

Logic tests:
```sh
cd Kairo
swift test
```

UI / device tests are not part of the SPM target. Use Xcode directly or XcodeBuildMCP if you have it configured.
