#!/usr/bin/env bash
#
# package-app.sh — assemble a distributable bar-helper.app from the release
# build, then (optionally) sign, notarize, staple, and zip it.
#
# Signing and notarization are gated on environment variables so the script
# runs end-to-end with no Apple credentials (producing an unsigned bundle for
# local use) and upgrades to a fully notarized artifact in CI when secrets are
# present.
#
# Usage:
#   scripts/package-app.sh [VERSION]
#
# Environment (all optional):
#   CODESIGN_IDENTITY   Developer ID Application identity for `codesign`.
#                       When unset, the bundle is left unsigned.
#   NOTARY_PROFILE      `xcrun notarytool` keychain profile name. When set
#                       (and the bundle is signed), the zip is submitted for
#                       notarization and the app is stapled.
#
# Outputs (under dist/):
#   bar-helper.app          the application bundle
#   bar-helper-<ver>.zip    zipped bundle for distribution / Homebrew cask
#   bar-helper-<ver>.zip.sha256   checksum for the cask `sha256` stanza
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

# --- Optional code signing -------------------------------------------------
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
	echo "==> Code signing with identity: ${CODESIGN_IDENTITY}"
	codesign --force --options runtime --timestamp \
		--sign "${CODESIGN_IDENTITY}" "${APP_DIR}"
	codesign --verify --deep --strict --verbose=2 "${APP_DIR}"
else
	echo "==> CODESIGN_IDENTITY not set — leaving bundle unsigned"
fi

# --- Zip -------------------------------------------------------------------
ZIP="${DIST}/${APP_NAME}-${VERSION}.zip"
echo "==> Creating ${ZIP}"
rm -f "${ZIP}"
# ditto preserves the bundle structure and resource forks for notarization.
/usr/bin/ditto -c -k --keepParent "${APP_DIR}" "${ZIP}"

# --- Optional notarization -------------------------------------------------
if [[ -n "${NOTARY_PROFILE:-}" && -n "${CODESIGN_IDENTITY:-}" ]]; then
	echo "==> Submitting for notarization (profile: ${NOTARY_PROFILE})"
	xcrun notarytool submit "${ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait
	echo "==> Stapling ticket"
	xcrun stapler staple "${APP_DIR}"
	# Re-zip the stapled app so the distributed artifact carries the ticket.
	rm -f "${ZIP}"
	/usr/bin/ditto -c -k --keepParent "${APP_DIR}" "${ZIP}"
else
	echo "==> Skipping notarization (need CODESIGN_IDENTITY and NOTARY_PROFILE)"
fi

# --- Checksum --------------------------------------------------------------
echo "==> Computing SHA-256"
shasum -a 256 "${ZIP}" | tee "${ZIP}.sha256"

echo "==> Done. Artifacts in ${DIST}/"
