# Changelog

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
