# Changelog

## 1.14.0

- Fixed MIDI playing silence while the time counted up. Wine hands MIDI to the
  first sequencer device it finds, which on Debian is "Midi Through"
  (`snd_seq_dummy`) - a loopback that discards everything. The synthesiser was
  connected to nothing. Confirmed from the sequencer's own table: Winamp's
  client wired to Midi Through, TiMidity with no connections at all, and no
  audio on the sink while direct playback of the same file peaked at 3686
- The loopback is now blacklisted so the synth is the only MIDI device. It
  cannot be rewired from outside - `aconnect` answers "Connection failed
  (Invalid argument)"
- The synthesiser is started from the user's autostart rather than the
  packaged daemon, which runs as a system user and cannot reach a per-session
  PulseAudio - the reason `service timidity start` kept failing


## 1.13.0

- Fixed Winamp copies piling up, one per file opened. Opening a file starts a
  second `winamp.exe` that passes the name to the running instance and should
  then exit - but it had loaded `winealsa.drv` on the way in, wedged a thread
  in the kernel's ALSA sequencer, and could never exit. The launcher now hands
  files over with the driver disabled, since a hand-off has no use for MIDI,
  and cleans the messenger up afterwards. Measured: opening three files in a
  row now leaves one running Winamp and creates no new zombies, where before
  it left four processes that could not be killed
- Added `winamp-cleanup`, which clears the windows of dead Winamps. Those
  windows stay on screen looking like running copies, and are still registered
  with wineserver, so Winamp's "is one already running?" check can find a
  corpse. The launcher runs it before every start; `winamp-cleanup --all` also
  closes the running copies
- Neither can remove the zombies themselves. A thread in uninterruptible sleep
  ignores SIGKILL, and the stale sequencer connections cannot be released from
  userspace either - `aconnect -d` answers "No subscription is found". Only a
  reboot clears them


## 1.12.0

- MIDI is on by default again. 1.10.0 and 1.11.0 disabled Wine's MIDI driver
  and then Winamp's MIDI plugin to stop the unkillable-process problem, which
  worked - and left the player unable to play a `.mid` at all. That is the
  worse failure of the two, so the default is back to MIDI working, with the
  cost stated plainly
- Replaced the "Winamp (MIDI enabled)" entry with **Winamp (no MIDI)**, which
  reverses the trade for a session where a clean exit matters more
- Measured both ways round: with the driver loaded, MIDI reaches the
  synthesiser and one thread wedges in the ALSA sequencer; with it disabled,
  no stuck thread and no MIDI


## 1.11.0

- Fixed "unknown MMSYSTEM error" when playing a MIDI file. Disabling
  winealsa.drv in 1.10.0 left Winamp with no MIDI ports but its `in_midi`
  plugin still enabled, so pressing play on a `.mid` threw a modal error. The
  plugin is now disabled alongside the driver, and the same `.mid` that
  produced the error now loads and plays nothing rather than complaining
- The MIDI launcher is a small script rather than an environment variable on
  the desktop entry. It enables the plugin, starts Winamp, and disables the
  plugin again ten seconds later - not on exit, because a Winamp started with
  MIDI often never exits, which would leave the plugin armed for the next
  ordinary launch. Verified: enabled at +6s, put away by +16s, MIDI still
  reaching the synthesiser in the running session


## 1.10.0

- The winealsa.drv workaround moved from the launcher into the Wine prefix
  registry. On the launcher it only covered starting Winamp from the menu or
  the desktop icon; "Open With" from a file manager sets `WINEPREFIX` and
  nothing else, so it still wedged a thread and still could not be closed.
  Measured with no environment variable set at all: one stuck thread before
  the registry change, none after
- Winamp's crash handler is disabled. It mails its report to bug@winamp.com
  through the default mail client, which under Wine appears as a mail account
  setup dialog out of nowhere
- Added a second menu entry, "Winamp (MIDI enabled)", for when MIDI matters
  more than a clean exit


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
