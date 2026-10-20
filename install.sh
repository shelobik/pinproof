#!/usr/bin/env bash
# pinproof installer — for systems without git (e.g. Batocera). Downloads the pinproof script (and optionally vpxtool),
# puts it in your PATH and creates a config template. Run it again to update.
#
#   curl -fsSL https://raw.githubusercontent.com/shelobik/pinproof/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/shelobik/pinproof/main/install.sh | bash -s -- --with-vpxtool
#
# Asks for your WoVP API key and for the official WoVP Patcher (folder, .zip/.rar or wovp_script.vbs) if the config
# has none; the telemetry script is copied to ~/.local/share/pinproof/.
#
# Options: --with-vpxtool   also install vpxtool (needed for `pinproof patch`)
#          --dir DIR        install directory (default: ~/.local/bin; /userdata/system/bin on Batocera)
#          --ref REF        git tag or branch to install (default: main)
#          --api-key KEY    set the API key without asking
#          --patcher PATH   official WoVP Patcher (folder, .zip/.rar or wovp_script.vbs) without asking
set -euo pipefail

REPO=shelobik/pinproof
VPXTOOL_VERSION=v0.38.0
REF=main
WITH_VPXTOOL=0
DIR=""
API_KEY=""
PATCHER=""
while [ $# -gt 0 ]; do
    case "$1" in
        --with-vpxtool) WITH_VPXTOOL=1 ;;
        --dir) DIR=$2; shift ;;
        --ref) REF=$2; shift ;;
        --api-key) API_KEY=$2; shift ;;
        --patcher) PATCHER=$2; shift ;;
        -h|--help) sed -n '2,16s/^# \{0,1\}//p' "$0" 2>/dev/null || true; exit 0 ;;
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
screenshot_command = ""                        # empty = whole desktop with the first tool found (spectacle, grim, scrot, ...)
EOF
    )
    say "Created $CONF"
else
    say "Kept existing $CONF"
fi

# API key: set it if the config has none (asked on the terminal, also when piped from curl)
if grep -q '^api_key = ""' "$CONF"; then
    if [ -z "$API_KEY" ] && [ -r /dev/tty ] && { : >/dev/tty; } 2>/dev/null; then
        printf 'WoVP API key (https://worldofvirtualpinball.com/en/challenge/settings?tab=general), Enter = later: ' >/dev/tty
        read -r API_KEY </dev/tty || API_KEY=""
    fi
    API_KEY=$(printf '%s' "$API_KEY" | tr -d '[:space:]')
    if [ -n "$API_KEY" ]; then
        printf '%s' "$API_KEY" | grep -Eq '^[A-Za-z0-9_-]+$' || fail "the API key has unexpected characters"
        sed -i "s|^api_key = \"\"|api_key = \"$API_KEY\"|" "$CONF"
        if who=$("$DIR/pinproof" --config "$CONF" challenges 2>/dev/null | head -n1); then
            who=${who#*(}; say "API key OK — ${who%)*}"
        else
            say "API key saved, but WoVP did not accept it — check it in $CONF"
        fi
    else
        say "No API key yet: add it to $CONF (api_key = \"...\")."
    fi
fi

# WoVP telemetry script (wovp_script.vbs from the official WoVP Patcher; not distributed with pinproof)
ask_tty() {  # ask_tty PROMPT -> answer on stdout ('' without a terminal)
    if [ -r /dev/tty ] && { : >/dev/tty; } 2>/dev/null; then
        printf '%s' "$1" >/dev/tty
        local a=""; read -r a </dev/tty || a=""; printf '%s' "$a"
    fi
}
find_wovp_script() {  # find_wovp_script PATH -> path of wovp_script.vbs (unpacks .zip/.rar into $tmp)
    local p=$1 x="$tmp/patcher"
    case "$p" in
        *.zip) mkdir -p "$x"; python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$p" "$x" || return 1; p=$x ;;
        *.rar) mkdir -p "$x"
               if command -v unrar >/dev/null 2>&1; then unrar x -o+ -inul "$p" "$x/" || return 1
               elif command -v bsdtar >/dev/null 2>&1; then bsdtar -xf "$p" -C "$x" || return 1
               elif command -v 7z >/dev/null 2>&1; then 7z x -y -o"$x" "$p" >/dev/null || return 1
               else say "  can't unpack .rar here (no unrar/bsdtar/7z) — unpack it and give the folder"; return 1; fi
               p=$x ;;
    esac
    if [ -d "$p" ]; then p=$(find "$p" -name wovp_script.vbs -type f 2>/dev/null | head -n1); fi
    [ -n "$p" ] && [ -f "$p" ] && grep -q 'Sub WoVP_Timer_Timer' "$p" && printf '%s' "$p"
}
SCRIPT_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/pinproof
if [ -n "$PATCHER" ] || grep -q '^patcher = ""' "$CONF"; then
    [ -n "$PATCHER" ] || PATCHER=$(ask_tty 'Official WoVP Patcher (folder, .zip/.rar or wovp_script.vbs), Enter = later: ')
    PATCHER=${PATCHER#[\"\']}; PATCHER=${PATCHER%[\"\']}; PATCHER=${PATCHER/#\~/$HOME}
    if [ -n "$PATCHER" ]; then
        if src=$(find_wovp_script "$PATCHER"); then
            mkdir -p "$SCRIPT_DIR"
            install -m 644 "$src" "$SCRIPT_DIR/wovp_script.vbs"
            sed -i "s|^patcher = .*|patcher = \"$SCRIPT_DIR/wovp_script.vbs\"           # copied from the official WoVP Patcher|" "$CONF"
            say "WoVP telemetry script copied to $SCRIPT_DIR/wovp_script.vbs"
        else
            say "No WoVP telemetry script (wovp_script.vbs) found in $PATCHER — set \`patcher\` in $CONF later."
        fi
    else
        say "No WoVP Patcher yet: needed for \`pinproof patch\` — run the installer again with --patcher PATH."
    fi
fi

case ":$PATH:" in
    *":$DIR:"*) ;;
    *) say "Note: $DIR is not in your PATH — run it as $DIR/pinproof or add the folder to PATH." ;;
esac
say "Done. Try: pinproof challenges"
