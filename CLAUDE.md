# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

`bar-helper` is a native macOS **menu bar manager** — it hides, organizes, and styles the icons in the system
menu bar. The north star is feature parity with **Bartender** and **Ice** (full-clone ambitions), delivered
MVP-first. The product spec lives in [`docs/requirements.md`](docs/requirements.md); treat that file as the
source of truth for *what* to build and the rationale behind each requirement. This file covers *how* to work
in the repo.

> Status: scaffolded as a SwiftPM executable (`bar-helper`). Source lives in `Sources/BarHelper`, tests in
> `Tests/BarHelperTests`. The build/test commands below are real.

## Stack & baseline

- **Language:** Swift.
- **Frameworks:** AppKit + SwiftUI, hybrid. Use **AppKit** for the menu bar / status items / system
  integration (~70%), **SwiftUI** for the settings window and preference panes (~30%). AppKit owns anything
  touching `NSStatusBar`/`NSStatusItem`; SwiftUI is for configuration UI only.
- **OS baseline:** macOS 16+. **macOS 26 "Tahoe" is the must-not-break target** — Tahoe changed the
  under-the-hood menu-bar model and broke both reference apps, so every menu-bar behavior must be validated
  there first.
- **App type:** menu-bar agent — no Dock icon, no main window. Set `LSUIElement` / "Application is agent (UIElement)"
  in the app's Info.plist.

## Build / run / test commands

The package is a SwiftPM executable; build and run everything from the CLI.

```bash
# Build (Debug)
swift build

# Run the menu-bar agent (appears in the menu bar, not the Dock)
swift run bar-helper
# ...or run the built binary directly:
"$(swift build --show-bin-path)/bar-helper"

# Test (all)
swift test

# Test (a single case or whole suite)
swift test --filter BarHelperTests.ModelTests/testUndoRedoRoundTrip
swift test --filter BarHelperTests.ModelTests

# Format & lint
swift format --in-place --recursive Sources Tests   # or: swiftlint --fix
markdownlint-cli2 "**/*.md"                          # docs lint (config in repo)
```

For non-Swift files (Markdown/YAML/JSON), this user's global tooling prefers `prettier`, `markdownlint-cli2`,
and `jq`/`fx`.

> Note: model/store logic is covered by headless unit tests; the menu-bar manipulation and SwiftUI panes
> require a live GUI session and Screen Recording / Accessibility grants to exercise fully.

### Packaging & release (REQ-C11 — free GitHub + Homebrew)

bar-helper is **free and unsigned** — no paid Apple Developer ID, no notarization. The cask downloads a zipped
`.app` from GitHub Releases. The bundle is **ad-hoc signed** (required to launch on Apple Silicon); users clear
Gatekeeper once on first launch. Bundle metadata lives in `Resources/Info.plist` (the authoritative
`LSUIElement` / `LSMinimumSystemVersion` source — the SwiftPM deployment target is deliberately lower to avoid
the toolchain's 16→26 deployment-version override).

```bash
# Build dist/bar-helper.app + zip + sha256 (ad-hoc signed, free)
make app VERSION=0.1.0           # or: scripts/package-app.sh 0.1.0
```

- `scripts/package-app.sh` assembles the bundle, stamps the version via `PlistBuddy`, and `codesign --sign -`
  (ad-hoc) by default. It honors `CODESIGN_IDENTITY` only if someone later has a real Developer ID — not
  required.
- `.github/workflows/release.yml` runs on a `v*` tag: tests, packages, publishes the GitHub release, and
  commits the bumped `version`/`sha256` back into `Casks/bar-helper.rb`. No signing secrets needed.
- `Casks/bar-helper.rb` is the cask; its `caveats` document the Gatekeeper step. Placeholder `url`/`sha256` are
  inert until the first release — **update the GitHub `<owner>`** in the cask `url`/`homepage` and the README
  tap command before publishing.

## Architecture (the big picture)

The non-obvious core is **how menu-bar items get hidden**, because macOS exposes no sanctioned API for it.
Read these pieces together to understand the system:

- **Separator status-item, expand-to-hide.** bar-helper owns one or more of its own `NSStatusItem`s acting
  as **separators** (chevrons). Setting a separator's length to an *expanding* value pushes every status item
  to its left off the visible edge of the menu bar — the items still exist, they're just shoved out of view.
  Collapsing the separator reveals them. This is the same trick Bartender and Ice use.
- **Three sections:** **visible** (always shown), **hidden** (revealed on demand), and **always-hidden**
  (only shown via an explicit action). Two separators bound these sections.
- **`MenuBarManager` controller.** A single AppKit-side controller owns the separator `NSStatusItem`(s),
  tracks which real items belong to which section, and performs the expand/collapse. This is the heart of the
  app — most logic hangs off it.
- **Permissions gate.** At launch, check **Screen Recording** (needed to read the menu-bar layout and apply
  styling — *not* to record) and **Accessibility** (needed to move/interact with items). Missing permission
  must degrade gracefully (limited mode) rather than crash or silently no-op, and the request flow must
  clearly state "bar-helper does not record your screen."
- **Reveal triggers + auto-rehide.** Revealing hidden items can be driven by click, hover, scroll/swipe in
  the menu bar, or a global hotkey. A configurable timer auto-rehides after inactivity.
- **Settings store.** Section assignments, styling, hotkeys, and profiles are persisted (UserDefaults +
  `Codable` profiles) and shared between the AppKit controller and the SwiftUI settings views — keep this a
  single source of truth, not duplicated state.

Because none of the menu-bar manipulation rests on public API, it is **fragile across macOS updates**.
Validate against the latest macOS beta early; treat OS-version regressions as release-blocking (see
`docs/requirements.md`).

## Where things live (requirement → source)

The spec's `REQ-` IDs map onto the source so you can navigate by feature:

- Sections + expand-to-hide (REQ-C01): `MenuBar/MenuBarSection.swift`, `MenuBar/Separator.swift`,
  `MenuBar/MenuBarManager.swift`
- Reveal triggers + auto-rehide (REQ-C02/C03): `MenuBar/RevealController.swift`
- Arrange / search / styling / profiles / hotkeys UI (REQ-C04..C09): `UI/SettingsView.swift`
- Secondary hidden-items bar (REQ-C10): `MenuBar/HiddenItemsPanel.swift`
- Hotkeys engine (REQ-C07): `Hotkeys/`
- Launch at login (REQ-C08): `Login/LaunchAtLogin.swift`
- Profiles + persistence + undo/redo (REQ-C09/I03/I04): `Settings/SettingsStore.swift`
- No telemetry (REQ-B01): `Privacy/Telemetry.swift`
- Permissions flow (REQ-I05/X02): `Permissions/PermissionsManager.swift`
- Primary control item/menu: `MenuBar/ControlItem.swift`

## Conventions & non-negotiables

These are lessons baked in from how the reference apps lost user trust or fell behind:

- **No telemetry or analytics, ever.** Privacy is a first-class feature, not a setting. (Bartender's silent
  addition of Amplitude telemetry in 2024 triggered a mass exodus — bar-helper must never repeat this.)
- **Stay current with macOS.** Supporting new macOS releases promptly is a release priority, not a backlog
  item. (Ice's lag on Tahoe support was a top user complaint.)
- **Honest permission strings.** `NSScreenCaptureUsageDescription`/Accessibility prompts must explain *why*
  access is needed and explicitly state the screen is not recorded.
- **Reliability over features under the current OS model.** No ghost clicks, cursor hijacking, runaway memory,
  or constant reindexing — these are the exact failures that broke Bartender on Tahoe.
