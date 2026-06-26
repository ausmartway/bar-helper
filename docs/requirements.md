# bar-helper — Product Requirements

> Research-derived requirements for `bar-helper`, a native macOS menu bar manager. Requirements are distilled
> from two reference apps: **Bartender** and **Ice**. Shared capabilities both apps offer become **MUST-HAVE**
> requirements; each app's documented failures become **SHOULD-HAVE** differentiators that bar-helper must beat.
>
> ID scheme: `REQ-Cxx` = core/must-have, `REQ-Bxx` = derived from Bartender's failures, `REQ-Ixx` = derived
> from Ice's failures.

## 1. Purpose & vision

bar-helper takes control of the macOS menu bar: it hides clutter, reveals it on demand, lets the user arrange
icons, and styles the bar. The **north star is full feature parity** with Bartender and Ice. Delivery is
**MVP-first** — the separator-based hide/show in §3 is the minimum shippable product; everything else layers on
top. The two principles that distinguish bar-helper from its predecessors are **privacy** (zero telemetry) and
**staying current with macOS** (no lag on new releases).

## 2. Reference apps

- **Bartender** — the long-standing commercial leader (closed-source, paid). Studied for its mature feature
  set; cautionary tale for its 2024 ownership change + silent telemetry, and its instability on macOS 26 Tahoe.
- **Ice** — the popular free, open-source alternative (`jordanbaird/Ice`, GPL-3.0, macOS 14+). Studied for its
  clean baseline feature set; cautionary tale for slow new-OS support and performance/stability gaps.

## 3. Shared capabilities → MUST-HAVE requirements

Both apps implement all of these; bar-helper must too.

- **REQ-C01 — Separator-based hide/show.** Provide user-controllable separator items that divide the menu bar
  into **visible**, **hidden**, and **always-hidden** sections. Hiding works by expanding a separator to push
  items off the visible edge (items are never destroyed). *(Core mechanism — MVP.)*
- **REQ-C02 — Reveal on demand.** Hidden items can be revealed by **click** on the menu bar, **hover**,
  **scroll/swipe** in the menu bar, and a **global hotkey**. Each trigger is individually toggleable.
- **REQ-C03 — Auto-rehide.** After revealing, items automatically re-hide after a configurable delay and/or on
  loss of focus.
- **REQ-C04 — Command-drag arrangement.** The user can ⌘-drag menu-bar items between sections and reorder them,
  controlling both third-party and system (macOS) items.
- **REQ-C05 — Menu-bar styling.** Customize the bar's appearance: tint, border, shadow, and shape/profile.
- **REQ-C06 — Search hidden items.** Quickly find a hidden item by name via a search field/quick-open.
- **REQ-C07 — Global hotkeys.** Bindable shortcuts for toggling sections and other key actions.
- **REQ-C08 — Launch at login.** Optional auto-start as a menu-bar agent (no Dock icon).
- **REQ-C09 — Profiles / presets.** Save and switch between named menu-bar layouts/configurations.
- **REQ-C10 — Secondary reveal surface.** Offer an alternative to expanding the main bar — a separate
  strip/popover that lists hidden items (cf. Bartender Bar / Ice Bar) so the main bar stays uncluttered.
- **REQ-C11 — Free distribution via GitHub + Homebrew.** bar-helper is free and open source and must be
  installable/updatable via **Homebrew** as a cask (`brew install --cask bar-helper`), matching how the
  reference apps ship (e.g. `brew install --cask jordanbaird-ice`). The cask downloads a zipped `.app` from
  **GitHub Releases**, supports `brew upgrade`, and cleans up on `brew uninstall`/`--zap`. The app is
  distributed **without a paid Apple Developer ID**: it is **ad-hoc signed** (required to launch on Apple
  Silicon) but **not notarized**, so the cask and README must clearly document the one-time macOS Gatekeeper
  approval (System Settings → Privacy & Security → "Open Anyway", or clearing the quarantine flag). No paid
  signing/notarization is in scope.

## 4. Bartender's failures → differentiating requirements (SHOULD-HAVE)

What lost Bartender its users — bar-helper must do the opposite.

- **REQ-B01 — Zero telemetry.** No analytics frameworks, no usage reporting, no phone-home. Privacy is a
  first-class, non-configurable guarantee. *(Bartender silently shipped Amplitude telemetry in v5.0.52 in 2024,
  triggering mass uninstalls.)*
- **REQ-B02 — Transparent governance.** Open about ownership, data handling, and changes; honest, specific
  permission-usage strings. *(Bartender was quietly acquired by Applause Group with no disclosure.)*
- **REQ-B03 — Reliable manipulation under the current OS model.** No cursor hijacking, no ghost clicks, no
  unreliable rearrange/hide. *(These were Bartender 6's headline failures on macOS 26 Tahoe.)*
- **REQ-B04 — Bounded resource use.** No memory bloat and no constant reindexing of visible/hidden items;
  idle CPU must be negligible.

## 5. Ice's failures → differentiating requirements (SHOULD-HAVE)

Where Ice fell short — bar-helper must beat it.

- **REQ-I01 — Prompt new-OS support.** Track macOS betas and ship compatibility before/at GA; correct rendering
  on the latest release (no mis-tinted icons). *(Ice rendered icons a wrong shade of blue on Tahoe until a beta
  fix — its top complaint.)* OS-version regressions are release-blocking.
- **REQ-I02 — Performance & stability at scale.** Remain responsive and crash-free with a large number of
  menu-bar items.
- **REQ-I03 — Undo/redo.** Full undo/redo for section assignments and arrangement changes.
- **REQ-I04 — Complete, robust profiles.** Profiles (REQ-C09) must be reliable and complete, including quick
  switching — not a partial/under-developed feature.
- **REQ-I05 — Low-friction permissions.** A clear, one-time permission flow (Screen Recording + Accessibility)
  that explains *why* each is needed, states the screen is not recorded, avoids repeated re-prompting, and
  offers a usable **degraded mode** when permissions are absent.

## 6. Constraints & permissions

- **REQ-X01 — Platform.** Swift + AppKit/SwiftUI; macOS 16+ baseline with **macOS 26 "Tahoe" as the primary
  validation target** (its under-the-hood menu-bar changes broke both reference apps).
- **REQ-X02 — Permissions.** Requires **Screen Recording** (to read menu-bar layout and apply styling — not to
  record) and **Accessibility** (to move/interact with items).
- **REQ-X03 — No sanctioned API.** macOS exposes no public API to detect whether one's own icon is hidden, nor
  any sanctioned way to move other apps' items. The implementation works around the system and is therefore
  **inherently fragile across OS updates** — this fragility must be actively managed (early beta testing,
  regression tests) rather than assumed away.

## 7. Out of scope (for now) / open questions

- Distribution is decided: free, open source, GitHub Releases + Homebrew cask, ad-hoc signed, not notarized
  (REQ-C11). The app is free — there is no pricing/licensing model.
- Whether to pursue Mac App Store distribution (sandboxing likely conflicts with REQ-X02 permissions, and the
  app is intentionally unsigned/free).
- Multi-display / per-display menu-bar behavior — confirm priority.
- Localization scope for v1.

## 8. References

- Ice — source & README: <https://github.com/jordanbaird/Ice> · <https://github.com/jordanbaird/Ice/blob/main/README.md>
- Ice — Tahoe beta fix (mis-tinted icons): <https://micro.webology.dev/2026/02/19/jordan-bairds-ice-beta-fixed/>
- Bartender — official site: <https://www.macbartender.com/>
- Bartender — macOS 26 lag/instability: <https://www.heise.de/en/news/macOS-26-Lag-and-other-issues-with-menu-bar-tool-Bartender-6-11167978.html>
- Bartender — 2024 acquisition + telemetry reporting: <https://appleinsider.com/articles/24/06/05/bartender-apps-new-owner-has-burnt-years-of-good-will-with-a-lack-of-transparency> · <https://tidbits.com/2024/06/05/bartender-developer-explains-and-apologizes-for-quiet-acquisition/>
- Apple — `NSStatusBar` / `NSStatusItem`: <https://developer.apple.com/documentation/appkit/nsstatusbar> · <https://developer.apple.com/documentation/appkit/nsstatusitem>
