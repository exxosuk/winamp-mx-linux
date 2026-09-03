# Winamp on MX Linux — handover

**Version 2.1.1** · repo `exxosuk/winamp-mx-linux` · working copy `~/repos/winamp-mx-linux`

## What this is

An installer that puts Winamp 5.9 under Wine on MX 23 and applies the pile of
Wine workarounds needed to make it usable. Everything it needs is bundled, so it
still works if the upstream download disappears.

| File | Purpose |
| --- | --- |
| `winamp.sh` | installer; `apply_wine_fixes()` holds every workaround |
| `winamp-launch` | launcher |
| `winamp-cleanup` | kills leftover Wine processes |
| `winamp_latest_full.exe` | bundled installer (backup copy) |
| `WinampPluginSetup.exe` | bundled MIDI synth plugin |
| `midi demo.mid` | ~30s demo, added to the default playlist |
| `screenshot.png` | playlist track names blurred before publishing |

## Fixes that are in and verified

- **Startup 21s → 2–4s.** The delay was Wine process corpses still registered
  with `wineserver`. `winamp-cleanup` clears them.
- **`explorer.exe` being killed** by an `xvidmode.c:164` assertion — fixed with
  `UseXVidMode=N`. This, not the audio driver, was the cause of the lock-ups I
  first blamed on WASAPI.
- **MIDI works.** Use the plugin's internal synth `in_aSyFon` **with
  `winealsa.drv` disabled**. Both settings must agree: leaving `in_midi` enabled
  while disabling `winealsa.drv` produces "unknown MMSYSTEM error". Verified: 2s
  start, audio peak 1390, zero stuck threads, and a second MIDI file plays without
  locking up. The soundfont selection must be done by the installer — a user
  should never see that dialog.
- Crash reporter disabled.
- Jump-to-File key lag and the right-click audio stutter: output plugin and
  buffer size settings, applied by the installer.

## Known bad, do not re-litigate

- **MilkDrop is broken** under Wine — corruption plus "error compiling ps_2.0
  warp shader". The registry key is `MaxPSVersion`, not `nMaxPSVersion` (verified
  against the DLL string table; a misspelt key is silently ignored), but setting
  it correctly still does not fix it. AVS 2.93 works and is the one to keep.
- **Zombie Wine processes only clear on reboot.** Threads stuck in ALSA sequencer
  code (`snd_use_lock_sync_helper`) go into D-state, which is uninterruptible and
  ignores SIGKILL. `winamp-cleanup` handles the ordinary corpses; D-state ones it
  cannot touch.

## Testing notes

- Kill by PID. `pkill -f` matches the tool's own shell and kills the session.
- Do not send modifier keystrokes with `xdotool` — a stuck modifier once broke the
  keyboard and closed the user's other applications. Release modifiers explicitly
  if you must, and never `xdotool type` blind, it lands in whatever has focus.
- Useful measurements: `parec` plus RMS for audio, `strace -f -tt -T` for startup,
  `/proc/PID/task/*/wchan` for stuck threads.
