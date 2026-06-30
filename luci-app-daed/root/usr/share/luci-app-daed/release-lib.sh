#!/bin/sh

RELEASE_REPO="${DAED_RELEASE_REPO:-QiuSimons/luci-app-daed}"
RELEASE_API_URL="${DAED_RELEASE_API_URL:-https://api.github.com/repos/${RELEASE_REPO}/releases/latest}"
GITHUB_PROXY_PREFIX="${GITHUB_PROXY_PREFIX:-https://ghfast.top/}"
RELEASE_CACHE_DIR="${DAED_RELEASE_CACHE_DIR:-/tmp/luci-app-daed.release}"
RELEASE_CACHE_FILE="${RELEASE_CACHE_DIR}/latest.json"
RELEASE_CACHE_TTL="${DAED_RELEASE_CACHE_TTL:-900}"

fetch_text() {
	url="$1"
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "$url" 2>/dev/null
		return $?
	fi
	if command -v wget >/dev/null 2>&1; then
		wget -qO- "$url" 2>/dev/null
		return $?
	fi
	uclient-fetch -qO- "$url" 2>/dev/null
}

download_file() {
	url="$1"
	out="$2"
	if command -v curl >/dev/null 2>&1; then
		curl -fL "$url" -o "$out"
		return $?
	fi
	if command -v wget >/dev/null 2>&1; then
		wget -O "$out" "$url"
		return $?
	fi
	uclient-fetch -qO "$out" "$url"
}

download_url() {
	url="$1"
	case "$url" in
		https://github.com/*)
			printf '%s%s\n' "$GITHUB_PROXY_PREFIX" "$url"
			;;
		*)
			printf '%s\n' "$url"
			;;
	esac
}

detect_manager() {
	if command -v opkg >/dev/null 2>&1; then
		echo opkg
		return 0
	fi
	if command -v apk >/dev/null 2>&1; then
		echo apk
		return 0
	fi
	return 1
}

detect_arch() {
	pm="$1"
	if [ "$pm" = "opkg" ]; then
		opkg print-architecture | awk '/^arch / {print $2}' | tail -n 1
		return
	fi

	distrib_arch="$(sed -n "s/^DISTRIB_ARCH=['\"]\([^'\"]*\)['\"].*/\1/p" /etc/openwrt_release 2>/dev/null | head -n 1)"
	if [ -n "$distrib_arch" ]; then
		printf '%s\n' "$distrib_arch"
	else
		apk --print-arch
	fi
}

detect_sdk() {
	release="$(sed -n "s/^DISTRIB_RELEASE=['\"]\([^'\"]*\)['\"].*/\1/p" /etc/openwrt_release 2>/dev/null | head -n 1)"
	printf '%s\n' "$release" | grep -Eo '[0-9]+\.[0-9]+' | head -n 1
}

asset_ext() {
	case "$1" in
		apk) echo apk ;;
		*) echo ipk ;;
	esac
}

installed_version() {
	pm="$1"
	pkg="$2"

	if [ "$pm" = "apk" ]; then
		if apk info -e "$pkg" >/dev/null 2>&1; then
			apk list -I "$pkg" 2>/dev/null | awk -v p="$pkg" '
				$1 ~ "^" p "-" {
					sub("^" p "-", "", $1)
					print $1
					exit
				}
			'
		fi
	else
		opkg status "$pkg" 2>/dev/null | awk -F': ' '$1=="Version"{print $2; exit}'
	fi
}

version_ge() {
	a="$1"
	b="$2"
	[ -n "$a" ] && [ -n "$b" ] || return 1
	[ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -n 1)" = "$a" ]
}

release_payload() {
	now="$(date +%s)"
	if [ -s "$RELEASE_CACHE_FILE" ]; then
		mtime="$(date -r "$RELEASE_CACHE_FILE" +%s 2>/dev/null || echo 0)"
		if [ "$((now - mtime))" -lt "$RELEASE_CACHE_TTL" ]; then
			cat "$RELEASE_CACHE_FILE"
			return 0
		fi
	fi

	mkdir -p "$RELEASE_CACHE_DIR"
	tmp="${RELEASE_CACHE_FILE}.$$"
	payload="$(fetch_text "$RELEASE_API_URL" || true)"
	if printf '%s' "$payload" | grep -q '"browser_download_url"'; then
		printf '%s\n' "$payload" >"$tmp"
		mv "$tmp" "$RELEASE_CACHE_FILE"
		cat "$RELEASE_CACHE_FILE"
		return 0
	fi

	rm -f "$tmp"
	if [ -s "$RELEASE_CACHE_FILE" ]; then
		cat "$RELEASE_CACHE_FILE"
		return 0
	fi
	return 1
}

release_tag_version() {
	release_payload | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | sed 's/^daed_//'
}

release_urls() {
	release_payload | sed -n 's/.*"browser_download_url":[[:space:]]*"\([^"]*\)".*/\1/p'
}

resolve_daed_asset() {
	pm="$1"
	arch="$2"
	sdk="$3"
	ext="$(asset_ext "$pm")"
	urls="$(release_urls)"
	[ -n "$urls" ] || return 1

	if [ "$ext" = "apk" ]; then
		for pattern in \
			"/daed-[^/]*-${arch}-openwrt-${sdk}\\.apk$" \
			"/daed-[^/]*-${arch}-${sdk}\\.apk$" \
			"/daed-[^/]*-openwrt-${sdk}\\.apk$" \
			"/daed-[^/]*-${sdk}\\.apk$"
		do
			url="$(printf '%s\n' "$urls" | grep -E "$pattern" | head -n 1)"
			[ -n "$url" ] || continue
			printf '%s\n' "$url"
			return 0
		done
	else
		for pattern in \
			"/daed_[^/]*_${arch}-openwrt-${sdk}\\.ipk$" \
			"/daed_[^/]*_${arch}-${sdk}\\.ipk$" \
			"/daed_[^/]*_${arch}\\.ipk$"
		do
			url="$(printf '%s\n' "$urls" | grep -E "$pattern" | head -n 1)"
			[ -n "$url" ] || continue
			printf '%s\n' "$url"
			return 0
		done
	fi

	return 1
}
