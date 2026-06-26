# bar-helper developer tasks. See CLAUDE.md for the full toolchain notes.
.PHONY: build run test fmt lint app clean

# Build the debug binary.
build:
	swift build

# Run the menu-bar agent.
run:
	swift run bar-helper

# Run the headless unit tests.
test:
	swift test

# Format Swift sources (no-op if swift-format is unavailable).
fmt:
	swift format --in-place --recursive Sources Tests || true

# Lint Markdown docs (config in .markdownlint-cli2.jsonc).
lint:
	markdownlint-cli2 "**/*.md"

# Assemble the distributable .app (+ zip + sha256) under dist/.
# Pass VERSION=x.y.z to stamp a version; otherwise git describe is used.
# Set CODESIGN_IDENTITY / NOTARY_PROFILE to sign and notarize.
app:
	scripts/package-app.sh $(VERSION)

clean:
	rm -rf .build dist
