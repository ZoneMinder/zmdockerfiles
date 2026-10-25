#!/bin/sh
# Work out which zmrepo channel and zoneminder package version to install.
#
#   zm-version.sh [channel] [codename] [arch[,arch...]]
#
# channel  release      newest release-1.x channel that has packages for <codename> (default)
#          master       nightly development builds (odd minor versions, e.g. 1.39)
#          release-1.38 or any other zmrepo directory, used as is
# arch     one Debian architecture, or a comma-separated list. With a list, the newest version
#          that every architecture has.
#
# Prints shell assignments: ZM_CHANNEL=..., ZM_VERSION=... (for the first arch) and ZM_PIN=...
# ZM_PIN is the apt version to install on any of the listed architectures. Nightly versions end
# in a per-arch CI run ID (1.39.41~20261023.190.<run>.1-trixie1), so for master ZM_PIN keeps
# everything before it and lets apt match the rest: 1.39.41~20261023.190.*
set -eu

base="${ZMREPO_URL:-https://zmrepo.zoneminder.com/debian}"
channel="${1:-release}"
codename="${2:-trixie}"
arch="${3:-amd64}"

if [ "$channel" = release ]; then
    channel=$(curl -fsSL "$base/" \
        | grep -o 'href="release-[0-9.]*/"' | sed 's/^href="//; s/\/"$//' | sort -u -V -r \
        | while read -r c; do
            if curl -fsI "$base/$c/$codename/Release" >/dev/null 2>&1; then echo "$c"; break; fi
        done)
    [ -n "$channel" ] || { echo "zm-version: no release channel has packages for $codename" >&2; exit 1; }
fi

packages=$(curl -fsSL "$base/$channel/$codename/Packages")
# versions <arch>: every zoneminder version for that arch, as "<build> <version>" lines
versions() {
    printf '%s\n' "$packages" | awk -v arch="$1" -v nightly="$([ "$channel" = master ] && echo 1)" '
        /^Package: /             { pkg = ($2 == "zoneminder"); ok = 0; v = "" }
        pkg && /^Architecture: / { ok = ($2 == arch) }
        pkg && /^Version: /      { v = $2 }
        /^$/ && pkg && ok && v != "" { b = v; if (nightly) sub(/\.[0-9]+\.[0-9]+-[^-]*$/, "", b); print b, v; pkg = 0 }
        END { if (pkg && ok && v != "") { b = v; if (nightly) sub(/\.[0-9]+\.[0-9]+-[^-]*$/, "", b); print b, v } }'
}

first="${arch%%,*}"
builds=$(versions "$first" | cut -d' ' -f1 | sort -u)
for a in $(echo "$arch" | tr , ' '); do
    avail=$(versions "$a" | cut -d' ' -f1)
    builds=$(printf '%s\n' "$builds" | while read -r b; do
        if printf '%s\n' "$avail" | grep -Fxq -- "$b"; then echo "$b"; fi
    done)
done
build=$(printf '%s\n' "$builds" | sed '/^$/d' | sort -V | tail -1)
[ -n "$build" ] || { echo "zm-version: no zoneminder version for all of $arch in $channel/$codename" >&2; exit 1; }
version=$(versions "$first" | awk -v b="$build" '$1 == b { print $2 }' | sort -V | tail -1)
if [ "$channel" = master ]; then pin="$build.*"; else pin="$version"; fi

echo "ZM_CHANNEL=$channel"
echo "ZM_VERSION=$version"
echo "ZM_PIN=$pin"
