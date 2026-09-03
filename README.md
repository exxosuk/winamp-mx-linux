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

## What has been tested

Driven automatically against Wine 9.21 on MX 23, checking after every action
that Winamp was still running and that no error dialog had appeared:

* play, pause, unpause, stop, next, previous - all fine, track changes confirmed
  from the window title
* seek forward and back, volume up and down, shuffle, repeat - all fine
* AVS visualisation - opens, renders and animates (two captures two seconds
  apart differed by 55,352 pixels, so it is not a frozen frame)
* audio through WASAPI - confirmed working
* the playlist survives a restart - 12,895 entries reloaded
* MIDI playback, after installing the synthesiser: Wine's "no software
  synthesizer" error is gone and TiMidity reports `Connected From: 130:0` while
  Winamp plays a `.mid`

Not covered: the modal dialogs (Preferences, Open File, Jump To File, File
Info). They could not be driven reliably from a script under Wine, so they are
untested rather than known-good.

## Troubleshooting

### "Jump To File" takes seconds per keypress

This is much faster on Windows with the same Winamp, and the reason is not that
Linux is slower. NTFS keeps filenames in a case-insensitive B-tree index, so
looking one up is a single indexed seek. The filesystem under Wine is
case-*sensitive*, so to honour Windows' case-insensitive semantics Wine has to
read the entire directory and compare every entry - O(log n) becomes O(n), for
each lookup. Winamp checks every playlist entry as you type, so the cost lands
on every keystroke. The cost is
linear in how many files sit in the folder your music is in - measured under
Wine 9.21, one enumeration of a folder costs about 0.1 ms per file in it:

    50 files      7 ms
    250 files    27 ms
    1126 files  121 ms

With a few thousand playlist entries pointing into one large folder, that adds
up to seconds per keystroke. Splitting the music into subfolders (by artist, or
even just A-Z) is what fixes it - twenty-five folders of forty files each
enumerate about twenty-five times faster than one folder of a thousand.

Things that are *not* the cause, all measured rather than assumed: the
filesystem (an ext4 folder of the same size measured the same as NTFS via
ntfs-3g); the length of the path (a drive letter mapped straight at the music
folder made no difference); a `.ciopfs` marker, which Wine probes for to detect
a case-insensitive filesystem (1.36s vs 1.30s - noise); and long filenames
forcing 8.3 short-name generation (1.37s for short names against 1.56s for very
long ones, so at most 14%). What is left is the enumeration itself, about
110 microseconds per file in the folder.

### Audio stutters when a menu opens

DirectSound output shares badly with the UI thread under Wine, so opening a
menu interrupts the sound. The installer now selects `out_wasapi.dll` instead,
which does not have the problem.

If you still get stutter, the plugin to move to is `out_wave.dll`: it is the
only one of the three with a buffer setting you can raise (Preferences >
Plug-ins > Output > Configure). WASAPI deliberately has no buffer control - the
DLL carries no such setting at all - so there is nothing to turn up there.

### Winamp starts but no window ever appears

    xvidmode.c:164: xf86vm_free_modes: Assertion `modes[0].dmDriverExtra ==
    sizeof(XF86VidModeModeInfo *)' failed.

Wine's X11 driver asserts while enumerating video modes and takes `explorer.exe`
down with it, which leaves `winamp.exe` running with nothing on screen. A media
player has no business changing the screen mode, so the installer turns the
extension off:

    WINEPREFIX=~/.wine-winamp wine reg add "HKCU\Software\Wine\X11 Driver" \
        /v UseXVidMode /t REG_SZ /d N /f

### Visualisation

The two visualisers Winamp ships are not equally portable, and the difference
is what they render with:

| | renderer | works under Wine |
|---|---|---|
| **AVS** | software - draws into a pixel buffer on the CPU and blits it | yes |
| **MilkDrop 2** | Direct3D 9 with HLSL pixel shaders compiled by `d3dx9` | no |

Counting the imports in the two DLLs makes the point: `vis_avs.dll` mentions
`d3d9` not once, `vis_milk2.dll` mentions `d3dx9` thirteen times.


MilkDrop 2 does not work under Wine's built-in `d3dx9`, whichever way you point
it. With its pixel shaders on it cannot compile them:

    error compiling ps_2.0 warp shader: syntax error, unexpected KW_sampler_state

and with `MaxPSVersion=0` under `[settings]` in `Plugins/Milkdrop2/milk2.ini` it
stops erroring but never draws anything - you get whatever was on the desktop
behind its window - and then puts up "plug-in executed an illegal operation".

So the installer selects **AVS**, and also renames `vis_milk2.dll` to
`vis_milk2.dll.disabled` so MilkDrop does not sit in Preferences > Plug-ins
waiting to be picked. Nothing is deleted - rename it back to restore it.

If you want MilkDrop working rather than hidden, the fix is Microsoft's own
d3dx9 in place of Wine's:

    WINEPREFIX=~/.wine-winamp winetricks d3dx9

then set `visplugin_name=vis_milk2.dll` back in `winamp.ini`. That pulls
redistributable DLLs from Microsoft, so whether you want them is your call.

### MIDI, and why Winamp does not use Wine's MIDI driver

Winamp's own `in_midi` plugin hands MIDI to Wine's MIDI driver, which opens an
ALSA sequencer client. Closing that client wedges a thread inside the kernel:

    tid 33971  state=D (uninterruptible)  wchan=snd_use_lock_sync_helper

`D` state ignores SIGKILL by design, and the kernel's wait there is deliberately
infinite - the five-second timeout was removed upstream in 2017 because breaking
out early risked a use-after-free. So the thread never returns. In practice
that meant: the first MIDI file plays, the second locks Winamp up, the process
can never be killed and only a reboot clears it, and every later start of
Winamp took about twenty seconds because it waited on those corpses.

None of it is fixable from outside. `aconnect -d` cannot release the stale
subscriptions ("No subscription is found"), the sequencer module cannot be
reloaded while the corpses hold it, and Wine's documented `MidiPort` registry
setting no longer exists in current Wine.

The way out is not to use Wine's MIDI at all. This installer adds
[in_aSyFon](http://www.synthfont.com/in_aSyFon_news.html), a free Winamp input
plugin that renders MIDI to audio *inside* Winamp with a soundfont and sends it
out through the ordinary output plugin. No MIDI device is opened, so there is
nothing to wedge. `in_midi` is disabled so it cannot claim `.mid` first, and
`winealsa.drv` is switched off in the prefix registry since nothing needs it
any more.

Measured after the change: Winamp starts in **2 seconds** rather than 21, MIDI
plays, and there are **no wedged threads** - so nothing is left behind when it
closes.

A short demo MIDI is installed beside Winamp's own `demo.mp3` and seeded into
the playlist, so a fresh install can demonstrate MIDI without you finding a
file first. It was written for this project rather than borrowed, so there is
nothing here that is not ours to hand out. An existing playlist is never
replaced.

The soundfont is `/usr/share/sounds/sf2/TimGM6mb.sf2` (5 MB, installed by the
`timgm6mb-soundfont` package). The plugin asks for one on first run if it has
none, so the installer writes the setting up front. For much better sound,
`sudo apt install fluid-soundfont-gm` and point `SoundFont=` in
`AppData/Roaming/SynthFont/SyfonWA.ini` at the larger set.

### The visualisation judders

AVS renders at its own pace while the compositor presents at the screen's
refresh rate, and when the two disagree the effects appear to jump. Right-click
the AVS window > Settings > Display and cap the frame rate at your monitor's
refresh (60 here) to line them up.

## Notes

- The classic desktop installer is no longer easy to find by clicking
  around winamp.com - the site itself has pivoted to a mobile app and
  "Winamp For Artists" business, and the desktop download only exists
  now as this stable, unlisted URL. Because that could disappear without
  notice, a copy of the installer is kept in this repository:

      winamp_latest_full.exe   13,034,408 bytes
      sha256  fa09d24d7481dbdfc1cff6aaa92d2aec908e037a22a02346f6feeee5d6ba688e

  The script still fetches the live download first, so you get the current
  version when there is one, and falls back to this copy only when the
  download fails or returns something that is not a Windows executable.
  Both fallback paths are tested. The file is Winamp's own unmodified
  installer as served by download.winamp.com on 3 September 2026; it is
  redistributed here as freeware, and if Winamp's owners would rather it
  were not, removing it costs one commit.
- The installer is unsigned freeware from Winamp's own domain, not a
  third-party mirror - no adware bundling, unlike sites such as Softonic.
