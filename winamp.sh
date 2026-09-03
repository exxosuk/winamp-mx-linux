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

use_bundled_installer() {
    # The classic desktop download is not linked from winamp.com any more and
    # exists only at one unlisted URL, so a copy is kept beside this script.
    # It is only reached when the live download fails or hands back something
    # that is not a Windows executable.
    local bundled
    bundled="$(cd "$(dirname "$0")" && pwd)/winamp_latest_full.exe"
    if [ ! -f "$bundled" ]; then
        echo ""
        echo "ERROR: the download failed and there is no bundled copy beside this"
        echo "script. The download.winamp.com link may have moved - check"
        echo "https://winamp.com by hand."
        exit 1
    fi
    if ! file -b "$bundled" | grep -qi "PE32"; then
        echo "ERROR: the bundled installer is not a Windows executable."
        exit 1
    fi
    echo "    Falling back to the copy bundled with this script."
    cp "$bundled" "$INSTALLER"
}

apply_wine_fixes() {
    # Three things Winamp needs changed to behave under Wine. Each one was
    # found the hard way on MX 23 with Wine 9.21; see README.md for the detail.
    local winamp_exe="$1"
    local appdata="$WINE_PREFIX/drive_c/users/$USER/AppData/Roaming/Winamp"
    local ini="$appdata/winamp.ini"

    # (a) Wine's X11 driver asserts and kills explorer.exe while enumerating
    #     video modes, which leaves Winamp started but with no window at all:
    #     xvidmode.c:164: xf86vm_free_modes: Assertion failed. A media player
    #     has no need to change the screen mode, so turn the extension off.
    WINEPREFIX="$WINE_PREFIX" wine reg add "HKCU\\Software\\Wine\\X11 Driver" \
        /v UseXVidMode /t REG_SZ /d N /f >/dev/null 2>&1 || true

    # (b) DirectSound output stutters whenever a menu opens, because it shares
    #     badly with the UI thread under Wine. WASAPI does not.
    if [ -f "$ini" ]; then
        sed -i 's/^outname=.*/outname=out_wasapi.dll/' "$ini"
    else
        mkdir -p "$appdata"
        printf '[Winamp]\noutname=out_wasapi.dll\n' > "$ini"
    fi

    # (c) MilkDrop 2 does not work under Wine's built-in d3dx9, whichever way
    #     you point it. With shaders on it fails to compile them:
    #     "error compiling ps_2.0 warp shader ... unexpected KW_sampler_state".
    #     With MaxPSVersion=0 it stops erroring but never draws - you get the
    #     leftover desktop pixels in its window - and then faults with
    #     "plug-in executed an illegal operation". So select AVS instead, which
    #     needs no shaders and was tested rendering and animating here. MilkDrop
    #     stays installed; see README.md for how to get it going with native
    #     d3dx9 if you want it.
    if grep -q '^visplugin_name=' "$ini" 2>/dev/null; then
        sed -i 's/^visplugin_name=.*/visplugin_name=vis_avs.dll/' "$ini"
    else
        printf 'visplugin_name=vis_avs.dll\n' >> "$ini"
    fi

    #     Selecting AVS is not enough on its own: MilkDrop still appears in
    #     Preferences > Plug-ins, and picking it there gets you the corruption
    #     and the "illegal operation" box. Winamp finds visualisers by scanning
    #     Plugins/vis_*.dll, so renaming it takes it out of the list without
    #     deleting anything. Rename it back to re-enable it.
    local milkdll="$WINE_PREFIX/drive_c/Program Files/Winamp/Plugins/vis_milk2.dll"
    [ -f "$milkdll" ] && mv "$milkdll" "$milkdll.disabled"

    echo "    Output set to WASAPI, visualiser set to AVS, XVidMode disabled."
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

    echo "==> Checking the tools this script needs..."
    # Everything below is used further down. MX installs no Recommends
    # (APT::Install-Recommends "0"), so nothing can be assumed to arrive as a
    # side effect of another package - each one is checked for by hand.
    missing=""
    command -v curl                    >/dev/null 2>&1 || missing="$missing curl"
    command -v file                    >/dev/null 2>&1 || missing="$missing file"
    command -v wrestool                >/dev/null 2>&1 || missing="$missing icoutils"
    command -v icotool                 >/dev/null 2>&1 || missing="$missing icoutils"
    command -v update-desktop-database >/dev/null 2>&1 || missing="$missing desktop-file-utils"
    command -v aconnect                >/dev/null 2>&1 || missing="$missing alsa-utils"
    missing=$(printf '%s\n' $missing | sort -u | tr '\n' ' ')
    if [ -n "${missing// /}" ]; then
        echo "    Installing:$missing"
        # shellcheck disable=SC2086
        sudo apt install -y $missing
    else
        echo "    All present."
    fi

    echo "==> Checking for a MIDI synthesiser..."
    # Wine has no synthesiser of its own. Without one it says at startup:
    #   err:winediag:MIDIMAP_drvOpen No software synthesizer midi port found
    # and .MID/.KAR/.RMI files - which Winamp lists among the types it handles -
    # play silently. timidity-daemon publishes ALSA sequencer ports at boot,
    # which is what Wine looks for.
    if aconnect -l 2>/dev/null | grep -qiE "timidity|fluid"; then
        echo "    Found one already."
    else
        echo "    None found - installing TiMidity (you may be asked for your password)..."
        # timidity only *Recommends* a soundfont, and MX installs no
        # Recommends, so the soundfont has to be named explicitly or TiMidity
        # ends up with a config pointing at a file that was never installed.
        # timgm6mb is 6 MB against fluid-soundfont-gm's ~140 MB and works.
        sudo apt install -y timidity timidity-daemon timgm6mb-soundfont

        # Repair the shipped config if it references a soundfont that is not
        # here. Without this TiMidity exits with "Error reading configuration
        # file" and never publishes a port for Wine to find.
        if [ ! -f /etc/timidity/fluidr3_gm.cfg ] && [ -f /etc/timidity/timgm6mb.cfg ] \
           && grep -q '^source /etc/timidity/fluidr3_gm.cfg' /etc/timidity/timidity.cfg 2>/dev/null; then
            echo "    Pointing TiMidity at the soundfont that is actually installed..."
            sudo cp /etc/timidity/timidity.cfg /etc/timidity/timidity.cfg.pre-winamp
            sudo sed -i 's|^source /etc/timidity/fluidr3_gm.cfg|source /etc/timidity/timgm6mb.cfg|' \
                /etc/timidity/timidity.cfg
        fi

        sudo service timidity restart >/dev/null 2>&1 || true
        sleep 2
        if aconnect -l 2>/dev/null | grep -qi timidity; then
            echo "    MIDI synthesiser is up."
        else
            echo "    WARNING: TiMidity did not start. MIDI files will not play;"
            echo "    everything else is unaffected. Try: sudo service timidity start"
        fi
    fi

    echo "==> Setting up a dedicated 32-bit Wine prefix at $WINE_PREFIX..."
    export WINEPREFIX="$WINE_PREFIX"
    export WINEARCH=win32
    if [ ! -d "$WINE_PREFIX" ]; then
        wineboot --init >/dev/null 2>&1
    fi

    echo "==> Downloading the latest Winamp installer..."
    if ! curl -L --fail -o "$INSTALLER" "$DOWNLOAD_URL"; then
        echo "    Download failed."
        use_bundled_installer
    fi

    FILETYPE=$(file -b "$INSTALLER")
    if ! echo "$FILETYPE" | grep -qi "PE32"; then
        echo "    What came back is not a Windows executable (got: $FILETYPE)."
        use_bundled_installer
        FILETYPE=$(file -b "$INSTALLER")
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

    echo "==> Applying the fixes this install needs under Wine..."
    apply_wine_fixes "$WINAMP_EXE"

    echo "==> Creating the launcher..."
    mkdir -p "$APPS_DIR"
    cat > "$LAUNCHER" <<EOF
[Desktop Entry]
Type=Application
Name=Winamp
Comment=It really whips the llama's ass
Exec=env WINEPREFIX="$WINE_PREFIX" WINEDLLOVERRIDES="winealsa.drv=d" wine "$WINAMP_EXE"
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
