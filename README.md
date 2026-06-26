# bar-helper

Take control of your Mac menu bar. **bar-helper** hides the icons you don't need, keeps the ones you do, and
gives them back the moment you want them — so your menu bar stays clean without losing anything.

It's a free, native macOS app. **No accounts. No tracking. No analytics — ever.**

## Features

- **Hide the clutter.** Tuck away menu bar icons you rarely use into a hidden section.
- **Reveal on demand.** Bring hidden icons back by clicking, hovering, scrolling on the menu bar, or with a
  keyboard shortcut.
- **Always-hidden section.** Stash icons you almost never need so they stay out of sight until you ask.
- **Auto-rehide.** Revealed icons tidy themselves away again after a few seconds.
- **Hidden items bar.** Prefer not to expand the menu bar? Show your hidden icons in a separate strip instead.
- **Make it yours.** Tint, border, shadow, and corner styling for the menu bar.
- **Search.** Find any icon by name.
- **Keyboard shortcuts.** Toggle sections and open search without touching the mouse.
- **Profiles.** Save different layouts and switch between them instantly.
- **Launch at login.** Start automatically and stay out of the way (no Dock icon).

## Install

bar-helper is free and open source, released on [GitHub](https://github.com/) and installed through
[Homebrew](https://brew.sh):

```bash
# Add the tap once, then install:
brew tap <owner>/tap
brew install --cask bar-helper
```

To update later:

```bash
brew upgrade --cask bar-helper
```

> Replace `<owner>` with this repo's GitHub account. bar-helper requires macOS 16 or later and is built and
> tested against the latest macOS release.

## Approve it on first launch

bar-helper is free and **not notarized by Apple** (that requires a paid developer account). Because of this,
macOS Gatekeeper blocks it the first time you open it. This is expected — here's how to allow it:

1. Open bar-helper once (macOS will block it).
2. Go to **System Settings → Privacy & Security**, scroll down, and click **"Open Anyway"** next to bar-helper.

Or clear the quarantine flag in one command (Homebrew prints this path too):

```bash
xattr -dr com.apple.quarantine /Applications/bar-helper.app
```

## Permissions

The first time it runs, bar-helper asks for two permissions and explains each one when it asks:

- **Screen Recording** — used to read your menu bar's layout and apply styling. **bar-helper does not record
  your screen.**
- **Accessibility** — used to move and arrange your menu bar icons.

You can grant, review, or revoke these any time in **System Settings → Privacy & Security**. If you skip them,
bar-helper still runs in a limited mode and tells you what's unavailable.

## Using bar-helper

- Click the **bar-helper icon** in your menu bar to open its menu: toggle hidden items, show the hidden items
  bar, open **Settings…**, or quit.
- In your menu bar you'll see one or two **chevrons (›)**. Click a chevron to reveal or hide a section.
- Open **Settings** to choose which icons are hidden, set your reveal triggers and shortcuts, style the bar,
  and manage profiles.
- Changed your mind? **Undo and Redo** are at the top of the Settings window.

## Privacy

bar-helper collects nothing. There are no analytics, no telemetry, no network requests, and no identifiers. The
permissions above are used only to manage your menu bar on your own Mac.

## Uninstall

```bash
brew uninstall --cask bar-helper
```
