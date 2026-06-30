#!/bin/sh

set -eu

LIB="/usr/share/luci-app-daed/release-lib.sh"
[ -r "$LIB" ] || exit 1
. "$LIB"

PM="$(detect_manager || true)"
ARCH="$(detect_arch "$PM" 2>/dev/null || true)"
SDK="$(detect_sdk || true)"
INSTALLED="$(installed_version "$PM" daed 2>/dev/null || true)"
LATEST="$(release_tag_version | head -n 1 || true)"
ASSET=""

if [ -n "$PM" ] && [ -n "$ARCH" ] && [ -n "$SDK" ]; then
	ASSET="$(resolve_daed_asset "$PM" "$ARCH" "$SDK" 2>/dev/null | xargs -n1 basename 2>/dev/null || true)"
fi

printf 'installed=%s\n' "$INSTALLED"
printf 'latest=%s\n' "$LATEST"
printf 'asset=%s\n' "$ASSET"
