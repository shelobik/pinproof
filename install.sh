#!/usr/bin/env bash
# pinproof installer — for systems without git (e.g. Batocera). Downloads the pinproof script (and optionally vpxtool),
# puts it in your PATH and creates a config template. Run it again to update.
#
#   curl -fsSL https://raw.githubusercontent.com/shelobik/pinproof/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/shelobik/pinproof/main/install.sh | bash -s -- --with-vpxtool
#
# Options: --with-vpxtool   also install vpxtool (needed for `pinproof patch`)
#          --dir DIR        install directory (default: ~/.local/bin; /userdata/system/bin on Batocera)
#          --ref REF        git tag or branch to install (default: main)
set -euo pipefail

REPO=shelobik/pinproof
VPXTOOL_VERSION=v0.38.0
REF=main
WITH_VPXTOOL=0
DIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --with-vpxtool) WITH_VPXTOOL=1 ;;
        --dir) DIR=$2; shift ;;
        --ref) REF=$2; shift ;;
        -h|--help) sed -n '2,11s/^# \{0,1\}//p' "$0" 2>/dev/null || true; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
RAW=${PINPROOF_RAW:-https://raw.githubusercontent.com/$REPO/$REF}

say() { printf '%s\n' "$*"; }
fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

fetch() {  # fetch URL FILE
    if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
    else fail "need curl or wget"; fi
}

if [ -z "$DIR" ]; then
    if [ -d /userdata/system ] && command -v batocera-version >/dev/null 2>&1; then
        DIR=/userdata/system/bin          # Batocera: /userdata survives updates
    else
        DIR=$HOME/.local/bin
    fi
fi

# Python 3.11+ (tomllib)
command -v python3 >/dev/null 2>&1 || fail "python3 not found"
python3 -c 'import sys; sys.exit(sys.version_info < (3, 11))' \
    || fail "python3 $(python3 -c 'import platform; print(platform.python_version())') found, pinproof needs 3.11 or newer"

mkdir -p "$DIR"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

say "Installing pinproof ($REF) to $DIR"
fetch "$RAW/pinproof" "$tmp/pinproof"
head -n1 "$tmp/pinproof" | grep -q python3 || fail "download did not return the pinproof script"
install -m 755 "$tmp/pinproof" "$DIR/pinproof"
say "  $("$DIR/pinproof" --version)"

if [ "$WITH_VPXTOOL" = 1 ]; then
    case "$(uname -m)" in
        x86_64) arch=x86_64 ;;
        aarch64|arm64) arch=aarch64 ;;
        *) fail "no vpxtool build for $(uname -m)" ;;
    esac
    say "Installing vpxtool $VPXTOOL_VERSION ($arch) to $DIR"
    fetch "https://github.com/francisdb/vpxtool/releases/download/$VPXTOOL_VERSION/vpxtool-linux-$arch-$VPXTOOL_VERSION.tar.gz" "$tmp/vpxtool.tar.gz"
    tar xzf "$tmp/vpxtool.tar.gz" -C "$tmp"
    install -m 755 "$tmp/vpxtool" "$DIR/vpxtool"
    say "  $("$DIR/vpxtool" --version 2>/dev/null | head -n1)"
fi

CONF=${XDG_CONFIG_HOME:-$HOME/.config}/pinproof/config.toml
if [ ! -f "$CONF" ]; then
    mkdir -p "$(dirname "$CONF")"
    (umask 077; cat > "$CONF" <<EOF
# pinproof config — see https://github.com/$REPO#configure
api_key = ""                                   # https://worldofvirtualpinball.com/en/challenge/settings?tab=general
patcher = ""                                   # folder of the official WoVP Patcher (contains bin/wovp_script.vbs)
vpxtool = "$( [ "$WITH_VPXTOOL" = 1 ] && echo "$DIR/vpxtool" || echo vpxtool )"
log_dir = "~/vpin_logs"
screenshot_command = ""                        # e.g. "grim {file}"; use full paths
EOF
    )
    say "Created $CONF — add your api_key and the patcher folder."
else
    say "Kept existing $CONF"
fi

case ":$PATH:" in
    *":$DIR:"*) ;;
    *) say "Note: $DIR is not in your PATH — run it as $DIR/pinproof or add the folder to PATH." ;;
esac
say "Done. Try: pinproof challenges"
