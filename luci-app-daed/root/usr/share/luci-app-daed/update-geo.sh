#!/bin/sh

set -eu

BASE_DIR="/usr/share/v2ray"
[ -d "$BASE_DIR" ] || BASE_DIR="/usr/share/daed"
mkdir -p "$BASE_DIR"
mkdir -p "$BASE_DIR/backup"

STAMP="$(date +%Y%m%d-%H%M%S)"
UPDATED=""

download_one() {
	local kind="$1"
	local url tmp_file target

	case "$kind" in
		geoip) url="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" ;;
		geosite) url="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" ;;
		*)
			echo "usage: $0 <geoip|geosite|all>"
			exit 64
			;;
	esac

	target="${BASE_DIR}/${kind}.dat"
	tmp_file="/tmp/${kind}.dat"
	stage_file="${tmp_file}.new"

	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "$url" -o "$stage_file"
	elif command -v wget >/dev/null 2>&1; then
		wget -qO "$stage_file" "$url"
	else
		uclient-fetch -qO "$stage_file" "$url"
	fi

	[ -s "$stage_file" ] || {
		echo "Downloaded file is empty: $kind"
		exit 1
	}

	if [ -f "$target" ]; then
		cp "$target" "$BASE_DIR/backup/${kind}.dat.${STAMP}"
	fi

	mv "$stage_file" "$target"
	chmod 0644 "$target"
	UPDATED="${UPDATED}${kind} "
	echo "Updated ${kind} at ${target}"
}

KIND="${1:-}"
case "$KIND" in
	geoip|geosite)
		download_one "$KIND"
		;;
	all)
		download_one geoip
		download_one geosite
		;;
	*)
		echo "usage: $0 <geoip|geosite|all>"
		exit 64
		;;
esac

if [ -x /etc/init.d/daed ] && /etc/init.d/daed running >/dev/null 2>&1; then
	/etc/init.d/daed restart >/dev/null 2>&1 || true
fi
