# Winamp on MX Linux

Installs the latest classic Winamp desktop player under Wine, with an
application menu entry and a desktop icon, similar to a normal Windows
install.

![Winamp running on MX Linux under Wine](screenshot.png)

*Playlist track names are blurred in the screenshot.*

## Why not the Snap

Snap packages need snapd, which needs systemd running as PID 1. MX Linux
boots SysVinit by default, so the Winamp snap won't run without switching
your boot mode to systemd first (MX's own wiki confirms this, and its
forum has people hitting the same wall on MX 25 KDE). That's a bigger
change than installing a media player calls for, so this goes via Wine
directly instead - no boot mode change needed.

## What it does

1. Installs Wine (and icoutils, for icon extraction) if not already present
2. Creates a dedicated Wine prefix at ~/.wine-winamp, kept separate from
   any other Wine setup you may already have
3. Downloads the current installer from download.winamp.com
4. Runs it silently, with the Windows desktop shortcut and Start Menu
   entry options both switched on
5. Extracts Winamp's icon and builds a proper .desktop launcher, placed
   in both the application menu and on your Desktop

## Usage

    chmod +x winamp.sh
    ./winamp.sh install

Running it with no argument at all also installs - install is the
default. To remove it later:

    ./winamp.sh uninstall

## Known gotcha: silent audio

MX Linux's own wiki flags a sound bug in wine-staging 10.18, the version
MX Package Installer currently pulls in from the Enabled Repos - fixed in
wine-staging 11.5 or wine-legacy 9.21, both in the MX Test Repo. If
Winamp installs and opens fine but plays nothing, that's the first thing
to check: run "wine --version" and compare against what's in the Test
Repo.

## Notes

- The classic desktop installer is no longer easy to find by clicking
  around winamp.com - the site itself has pivoted to a mobile app and
  "Winamp For Artists" business, and the desktop download only exists
  now as this stable, unlisted URL. If it ever stops resolving, the
  script will tell you rather than failing silently (it checks the
  download is actually a Windows executable before handing it to Wine).
- The installer is unsigned freeware from Winamp's own domain, not a
  third-party mirror - no adware bundling, unlike sites such as Softonic.
