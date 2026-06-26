#!/usr/bin/env bash
#
# package-app.sh — assemble a distributable bar-helper.app from the release
# build, ad-hoc sign it, and zip it for a GitHub release / Homebrew cask.
#
# bar-helper is free and open source and is distributed WITHOUT a paid Apple
# Developer ID, so there is no Developer-ID signing or notarization. The bundle
# is ad-hoc signed, which is required for it to launch at all on Apple Silicon.
# Because it isn't notarized, macOS Gatekeeper asks the user to confirm it on
# first launch — see README.md.
#
# (If you later obtain a Developer ID, set CODESIGN_IDENTITY to that identity
# and the script will use it instead of an ad-hoc signature.)
#
# Usage:
#   scripts/package-app.sh [VERSION]
#
# Outputs (under dist/):
#   bar-helper.app                 the application bundle
#   bar-helper-<ver>.zip           zipped bundle for the GitHub release
#   bar-helper-<ver>.zip.sha256    checksum for the cask `sha256` stanza
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="bar-helper"
BUNDLE_EXEC="bar-helper"
DIST="dist"
APP_DIR="${DIST}/${APP_NAME}.app"

# Version: explicit arg, else `git describe`, else 0.0.0-dev.
VERSION="${1:-$(git describe --tags --always --dirty 2>/dev/null || echo "0.0.0-dev")}"
echo "==> Packaging ${APP_NAME} ${VERSION}"

echo "==> Building release binary"
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/${BUNDLE_EXEC}"
if [[ ! -x "${BIN_PATH}" ]]; then
	echo "error: built binary not found at ${BIN_PATH}" >&2
	exit 1
fi

echo "==> Assembling bundle at ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${BUNDLE_EXEC}"
cp "Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
printf 'APPL????' > "${APP_DIR}/Contents/PkgInfo"

# Stamp the real version into the bundled Info.plist (strip any leading "v").
PLIST="${APP_DIR}/Contents/Info.plist"
SHORT_VERSION="${VERSION#v}"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${SHORT_VERSION}" "${PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${SHORT_VERSION}" "${PLIST}"

# --- Code signing ----------------------------------------------------------
# Default to an ad-hoc signature ("-"). Apple Silicon refuses to run unsigned
# binaries, so this is the minimum required and is completely free.
SIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
if [[ "${SIGN_IDENTITY}" == "-" ]]; then
	echo "==> Ad-hoc signing (free; no Apple Developer ID)"
	codesign --force --sign - "${APP_DIR}"
else
	echo "==> Signing with Developer ID: ${SIGN_IDENTITY}"
	codesign --force --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_DIR}"
fi
codesign --verify --strict --verbose=2 "${APP_DIR}"

# --- Zip -------------------------------------------------------------------
ZIP="${DIST}/${APP_NAME}-${VERSION}.zip"
echo "==> Creating ${ZIP}"
rm -f "${ZIP}"
# ditto preserves the bundle structure and the code signature.
/usr/bin/ditto -c -k --keepParent "${APP_DIR}" "${ZIP}"

# --- Checksum --------------------------------------------------------------
echo "==> Computing SHA-256 (paste into Casks/bar-helper.rb)"
shasum -a 256 "${ZIP}" | tee "${ZIP}.sha256"

echo "==> Done. Artifacts in ${DIST}/"
