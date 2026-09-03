# Changelog

## 1.9.0

- Found and worked around the lock-up where Winamp would not close and could
  not be killed. Wine loads `winealsa.drv` for MIDI, it opens an ALSA
  sequencer client, and one thread wedges in `snd_use_lock_sync_helper` in
  uninterruptible state - which ignores SIGKILL, so the process can never be
  reaped. Three launches in a row each had exactly one such thread; with the
  driver disabled the count was zero and Winamp exited cleanly
- The launcher now sets `WINEDLLOVERRIDES="winealsa.drv=d"`. This costs MIDI
  playback, which is documented as an opt-in with the trade-off spelled out
- README documents both the symptom and how to diagnose it, since "cannot kill
  a process" is not something most people will think to blame on a sound driver


## 1.8.0

- MIDI playback confirmed working end to end: Wine's "no software synthesizer"
  error is gone and TiMidity shows the connection from Winamp while a `.mid`
  plays
- The installer now installs a soundfont explicitly and repairs TiMidity's
  config if it points at one that is not present. On MX this is not optional:
  `timidity` only Recommends a soundfont and MX sets
  `APT::Install-Recommends "0"`, so TiMidity would install and then refuse to
  start, with nothing to say why unless you ran it by hand
- Every external tool the script uses is now checked for and installed if
  missing - curl, file, icoutils, desktop-file-utils, alsa-utils - rather than
  assumed to be present
- The installer reports whether the synthesiser actually came up, instead of
  assuming the install worked


## 1.7.0

- The installer now installs `timidity` and `timidity-daemon` if no MIDI
  synthesiser is present, so `.MID`, `.KAR` and `.RMI` files play instead of
  failing silently. Not yet verified end to end on the development machine -
  installing packages needs root, which the test run did not have
- README explains why "Jump To File" is fast on Windows and slow under Wine
  (NTFS's case-insensitive index versus Wine enumerating the directory), and
  records the fixes that were tried and measured as ineffective: the `.ciopfs`
  marker and shorter filenames


## 1.6.0

- MilkDrop 2 is now renamed out of the way at install time rather than left in
  the plug-in list to be picked by accident. It cannot work under Wine: it
  renders through Direct3D 9 and compiles HLSL shaders with `d3dx9`, where AVS
  draws in software and needs no GPU API at all. Nothing is deleted - rename
  `vis_milk2.dll.disabled` back to restore it
- README explains the difference between the two visualisers


## 1.5.0

- The Winamp installer is now kept in the repository, because the classic
  desktop download exists at a single unlisted URL that could vanish. The
  script still downloads the live version first and only falls back to the
  bundled copy when the download fails or returns something that is not a
  Windows executable
- Both fallback paths tested: dead URL, and a URL that answers with HTML
  instead of an executable. The live download was checked too, to confirm the
  bundled copy is not used when it does not need to be


## 1.4.0

- README records a tested-features sweep: playback controls, seeking, volume,
  shuffle, repeat and AVS were each exercised and checked for crashes and error
  dialogs, and what was *not* covered is listed rather than left implied
- Documented that MIDI files will not play without a software synthesiser
  installed, which Wine reports at startup
- Documented the visualisation judder as a frame-pacing mismatch, and where to
  cap AVS's frame rate to fix it


## 1.3.0

- The installer now selects the AVS visualiser rather than MilkDrop 2. MilkDrop
  does not work under Wine's built-in d3dx9 either way round: with shaders it
  fails to compile them, and with `MaxPSVersion=0` it draws nothing and then
  faults. AVS needs no shaders, and was tested opening, rendering and animating
- README records what MilkDrop actually does under Wine, and how to get it
  working with native d3dx9 if you want it


## 1.2.1

- Fixed the MilkDrop setting being written under the wrong name. The key is
  `MaxPSVersion`; 1.2.0 wrote `nMaxPSVersion`, which MilkDrop ignores silently,
  so the shader error came back exactly as before


## 1.2.0

- The installer now applies the three Wine fixes itself, instead of leaving
  them written up in the README for you to do by hand:
  - output plugin set to `out_wasapi.dll`, which does not stutter when a menu
    opens the way DirectSound does
  - `nMaxPSVersion=0` for MilkDrop 2, so the visualisation stops failing on a
    shader Wine cannot compile
  - `UseXVidMode=N`, because Wine's X11 driver asserts while enumerating video
    modes and takes `explorer.exe` with it, leaving Winamp running with no
    window on screen
- README documents the no-window crash, and records that WASAPI has no buffer
  setting to raise - `out_wave.dll` is the plugin that has one


## 1.1.0

- Added a Troubleshooting section to the README covering three problems found
  running this under Wine 9.21 on MX 23: slow "Jump To File" typing, audio
  stutter when a menu opens, and the MilkDrop shader compile error
- The "Jump To File" entry records what was measured rather than guessed:
  the cost is Wine re-reading the whole folder per playlist entry, linear in
  the number of files in it, and is not caused by the filesystem or the path
- No change to `winamp.sh`


## 1.0.0

- Initial release: installs the latest Winamp under a dedicated Wine
  prefix, with an application menu entry and a desktop icon
- install and uninstall combined into one script, selected with a mode
  argument (`winamp.sh install` / `winamp.sh uninstall`)
