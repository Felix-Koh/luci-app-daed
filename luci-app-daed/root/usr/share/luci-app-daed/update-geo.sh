#!/bin/sh

set -eu

KIND="${1:-}"
case "$KIND" in
	geoip) URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" ;;
	geosite) URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" ;;
	*)
		echo "usage: $0 <geoip|geosite>"
		exit 64
		;;
esac

BASE_DIR="/usr/share/v2ray"
[ -d "$BASE_DIR" ] || BASE_DIR="/usr/share/daed"
mkdir -p "$BASE_DIR"
mkdir -p "$BASE_DIR/backup"

TARGET="${BASE_DIR}/${KIND}.dat"
STAMP="$(date +%Y%m%d-%H%M%S)"
TMP_FILE="/tmp/${KIND}.dat"

if command -v curl >/dev/null 2>&1; then
	curl -fL "$URL" -o "$TMP_FILE"
elif command -v wget >/dev/null 2>&1; then
	wget -O "$TMP_FILE" "$URL"
else
	uclient-fetch -qO "$TMP_FILE" "$URL"
fi

[ -s "$TMP_FILE" ] || {
	echo "Downloaded file is empty"
	exit 1
}

if [ -f "$TARGET" ]; then
	cp "$TARGET" "$BASE_DIR/backup/${KIND}.dat.${STAMP}"
fi

install -m 0644 "$TMP_FILE" "$TARGET"

if [ -x /etc/init.d/daed ] && /etc/init.d/daed running >/dev/null 2>&1; then
	/etc/init.d/daed restart >/dev/null 2>&1 || true
fi

echo "Updated ${KIND} at ${TARGET}"
