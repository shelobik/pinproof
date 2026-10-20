# Changelog

## 0.1.3 — 2026-10-20
- `install.sh` asks for the official WoVP Patcher (folder, .zip/.rar or `wovp_script.vbs`, or `--patcher PATH`) and copies the telemetry script to `~/.local/share/pinproof/`.

## 0.1.2 — 2026-10-20
- `submit` takes a screenshot of the whole desktop by default (first tool found: spectacle, grim, gnome-screenshot, scrot, maim, import); `screenshot_command` is optional.
- `install.sh` asks for the API key and checks it (`--api-key KEY` to give it without asking).

## 0.1.1 — 2026-10-20
- New `install.sh`: install and update without git (curl or wget), e.g. on Batocera.

## 0.1.0 — 2026-10-19
- First release: `patch`, `challenges`, `submit`, `logs`.
