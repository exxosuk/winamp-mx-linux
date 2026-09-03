#!/usr/bin/env bash
#
# winamp.sh
#
# Installs or removes the classic Winamp desktop player under Wine, with
# an application menu entry and a desktop icon, similar to how it would
# appear after a normal Windows install.
#
# Usage:
#   ./winamp.sh install     (default if no argument given)
#   ./winamp.sh uninstall
#
# Written for MX Linux (Debian-based, SysVinit by default) - see
# README.md for why this goes via Wine directly rather than the Winamp
# Snap.
#
set -euo pipefail

WINE_PREFIX="$HOME/.wine-winamp"
DOWNLOAD_URL="https://download.winamp.com/winamp/winamp_latest_full.exe"
INSTALLER="/tmp/winamp_latest_full.exe"
DESKTOP_DIR="$HOME/Desktop"
APPS_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/winamp"
LAUNCHER="$APPS_DIR/winamp.desktop"

usage() {
    echo "Usage: $0 [install|uninstall]"
    echo "  install    Download and set up Winamp under Wine (default)"
    echo "  uninstall  Remove the Wine prefix and launchers"
    exit 1
}

do_install() {
    echo "==> Checking for Wine..."
    if ! command -v wine >/dev/null 2>&1; then
        echo "    Not found - installing (you may be asked for your password)..."
        sudo dpkg --add-architecture i386
        sudo apt update
        sudo apt install -y wine
    else
        echo "    Found: $(wine --version)"
    fi

    echo "==> Checking for icoutils (needed to pull the icon out of the installer)..."
    if ! command -v wrestool >/dev/null 2>&1; then
        sudo apt install -y icoutils
    fi

    echo "==> Setting up a dedicated 32-bit Wine prefix at $WINE_PREFIX..."
    export WINEPREFIX="$WINE_PREFIX"
    export WINEARCH=win32
    if [ ! -d "$WINE_PREFIX" ]; then
        wineboot --init >/dev/null 2>&1
    fi

    echo "==> Downloading the latest Winamp installer..."
    curl -L --fail -o "$INSTALLER" "$DOWNLOAD_URL"

    FILETYPE=$(file -b "$INSTALLER")
    if ! echo "$FILETYPE" | grep -qi "PE32"; then
        echo ""
        echo "ERROR: what got downloaded isn't a Windows executable (got: $FILETYPE)."
        echo "The download.winamp.com link may have moved - check https://winamp.com by hand."
        exit 1
    fi
    echo "    Got a real installer: $FILETYPE"

    echo "==> Running the installer silently..."
    wine "$INSTALLER" /S /DS=1 /SMS=1

    echo "==> Locating winamp.exe..."
    WINAMP_EXE=""
    for candidate in \
        "$WINE_PREFIX/drive_c/Program Files/Winamp/winamp.exe" \
        "$WINE_PREFIX/drive_c/Program Files (x86)/Winamp/winamp.exe"
    do
        if [ -f "$candidate" ]; then
            WINAMP_EXE="$candidate"
            break
        fi
    done

    if [ -z "$WINAMP_EXE" ]; then
        echo "ERROR: install seemed to run but winamp.exe wasn't found where expected."
        echo "Have a look under $WINE_PREFIX/drive_c manually."
        exit 1
    fi
    echo "    Found: $WINAMP_EXE"

    echo "==> Extracting the Winamp icon..."
    mkdir -p "$ICON_DIR"
    wrestool -x -t 14 "$WINAMP_EXE" -o "$ICON_DIR/winamp.ico" 2>/dev/null || true
    if [ -f "$ICON_DIR/winamp.ico" ]; then
        icotool -x "$ICON_DIR/winamp.ico" -o "$ICON_DIR" >/dev/null 2>&1 || true
    fi
    ICON_PNG=$(find "$ICON_DIR" -name "*.png" 2>/dev/null | head -n1)
    ICON_PATH="${ICON_PNG:-$ICON_DIR/winamp.ico}"

    echo "==> Creating the launcher..."
    mkdir -p "$APPS_DIR"
    cat > "$LAUNCHER" <<EOF
[Desktop Entry]
Type=Application
Name=Winamp
Comment=It really whips the llama's ass
Exec=env WINEPREFIX="$WINE_PREFIX" wine "$WINAMP_EXE"
Icon=$ICON_PATH
Terminal=false
Categories=AudioVideo;Audio;Player;
StartupNotify=true
EOF
    chmod +x "$LAUNCHER"

    if [ -d "$DESKTOP_DIR" ]; then
        cp "$LAUNCHER" "$DESKTOP_DIR/winamp.desktop"
        chmod +x "$DESKTOP_DIR/winamp.desktop"
        echo "    Desktop icon placed at $DESKTOP_DIR/winamp.desktop"
    fi

    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true

    echo ""
    echo "==> Done. Look for Winamp in your application menu and on the desktop."
    echo "    First double-click of the desktop icon may need a right-click >"
    echo "    Allow Launching in KDE first - normal for any new .desktop file."
    echo "    Wine prefix: $WINE_PREFIX"
}

do_uninstall() {
    read -p "This will remove Winamp and its Wine prefix ($WINE_PREFIX). Continue? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi

    rm -rf "$WINE_PREFIX"
    rm -f "$LAUNCHER"
    rm -f "$DESKTOP_DIR/winamp.desktop"
    rm -rf "$ICON_DIR"
    update-desktop-database "$APPS_DIR" >/dev/null 2>&1 || true

    echo "Winamp removed. Wine itself was left installed."
}

MODE="${1:-install}"
case "$MODE" in
    install)
        do_install
        ;;
    uninstall)
        do_uninstall
        ;;
    *)
        usage
        ;;
esac
