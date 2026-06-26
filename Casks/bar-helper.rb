# Homebrew cask for bar-helper (REQ-C11).
#
# This is the canonical cask for the project's own tap. To install before the
# cask is accepted into homebrew-cask, users run:
#
#   brew install --cask <your-org>/tap/bar-helper
#
# The `version`, `sha256`, and release `url` are filled in by the release
# process (scripts/package-app.sh prints the sha256; CI updates this file).
# Until the first signed, notarized release is published, the placeholders
# below are intentionally inert.
cask "bar-helper" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/yulei-liu/bar-helper/releases/download/v#{version}/bar-helper-#{version}.zip",
      verified: "github.com/yulei-liu/bar-helper/"
  name "bar-helper"
  desc "Menu bar manager that hides, reveals, and styles status items"
  homepage "https://github.com/yulei-liu/bar-helper"

  # bar-helper relies on system APIs and the menu-bar model finalized in
  # macOS 16+ (validated on macOS 26 "Tahoe").
  depends_on macos: ">= :sequoia"

  app "bar-helper.app"

  # Quit the running agent before upgrading/uninstalling.
  uninstall quit: "app.barhelper.bar-helper"

  # Remove preferences and saved state on `brew uninstall --zap`.
  zap trash: [
    "~/Library/Preferences/app.barhelper.bar-helper.plist",
    "~/Library/Saved Application State/app.barhelper.bar-helper.savedState",
  ]
end
