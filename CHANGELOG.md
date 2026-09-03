# Changelog

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
