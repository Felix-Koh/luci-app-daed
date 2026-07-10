#!/bin/sh

set -eu

LIB="/usr/share/luci-app-daed/release-lib.sh"
[ -r "$LIB" ] || {
	echo "missing helper: $LIB"
	exit 1
}
. "$LIB"

PM="$(detect_manager || true)"
[ -n "$PM" ] || {
	echo "No supported package manager found"
	exit 1
}

ARCH="$(detect_arch "$PM" || true)"
SDK="$(detect_sdk || true)"
[ -n "$ARCH" ] && [ -n "$SDK" ] || {
	echo "Unable to detect OpenWrt architecture or SDK version"
	exit 1
}

INSTALLED_VER="$(installed_version "$PM" daed || true)"
ASSET_URL="$(resolve_daed_asset "$PM" "$ARCH" "$SDK" || true)"
[ -n "$ASSET_URL" ] || {
	echo "No daed package found for ${ARCH} / ${SDK}"
	exit 1
}

LATEST_VER="$(asset_version "$ASSET_URL" | head -n 1)"
[ -n "$LATEST_VER" ] || {
	echo "Unable to read latest package version"
	exit 1
}

TMP_EXT="$(asset_ext "$PM")"
TMP_FILE="/tmp/daed-update.${TMP_EXT}"
trap 'rm -f "$TMP_FILE"' EXIT

echo "Installed version: ${INSTALLED_VER:-not installed}"
echo "Latest version: ${LATEST_VER}"
echo "Downloading: $(basename "$ASSET_URL")"
download_file "$(download_url "$ASSET_URL")" "$TMP_FILE"

if [ "$PM" = "apk" ]; then
	apk add --allow-untrusted "$TMP_FILE"
else
	opkg install "$TMP_FILE"
fi

NEW_VER="$(installed_version "$PM" daed || true)"
if [ -z "$NEW_VER" ]; then
	echo "Update failed: daed is not installed after package operation"
	exit 1
fi

if ! version_ge "$NEW_VER" "$LATEST_VER"; then
	echo "Update failed: installed version ${NEW_VER} did not reach ${LATEST_VER}"
	exit 1
fi

echo "Updated daed to ${NEW_VER}"
