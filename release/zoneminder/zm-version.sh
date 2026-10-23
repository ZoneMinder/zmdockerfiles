#!/bin/sh
# Work out which zmrepo channel and zoneminder package version to install.
#
#   zm-version.sh [channel] [codename] [arch]
#
# channel  release      newest release-1.x channel that has packages for <codename> (default)
#          master       nightly development builds (odd minor versions, e.g. 1.39)
#          release-1.38 or any other zmrepo directory, used as is
#
# Prints shell assignments: ZM_CHANNEL=... and ZM_VERSION=...
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

version=$(curl -fsSL "$base/$channel/$codename/Packages" | awk -v arch="$arch" '
    /^Package: /      { pkg = ($2 == "zoneminder"); ok = 0 }
    pkg && /^Architecture: / { ok = ($2 == arch) }
    pkg && ok && /^Version: / { print $2 }' | sort -V | tail -1)
[ -n "$version" ] || { echo "zm-version: no zoneminder package for $arch in $channel/$codename" >&2; exit 1; }

echo "ZM_CHANNEL=$channel"
echo "ZM_VERSION=$version"
