# pinproof

Score proof tools for **Visual Pinball X on Linux**, for the high score challenges of
[World of Virtual Pinball](https://worldofvirtualpinball.com) (WoVP). The official WoVP Patcher and VPin Studio's score
submission are Windows-only; pinproof is a small command-line replacement:

| Command | What it does |
|---|---|
| `pinproof patch TABLE.vpx` | adds the WoVP telemetry to a table — the same patch as the official WoVP Patcher |
| `pinproof challenges` | lists the active challenges and your current score in each |
| `pinproof submit` | uploads a score screenshot to the matching challenge (WoVP WHSC API) |
| `pinproof logs [clean]` | lists the telemetry logs, deletes old ones |

One Python file, standard library only (Python 3.11+). `patch` needs [vpxtool](https://github.com/francisdb/vpxtool).
Not affiliated with WoVP. The WoVP telemetry script is **not** included: it is read from the official WoVP Patcher
download.

## Install

```sh
git clone https://github.com/shelobik/pinproof
install -m 755 pinproof/pinproof ~/.local/bin/
```

**vpxtool** (only for `patch`): download the Linux build from the
[vpxtool releases](https://github.com/francisdb/vpxtool/releases) and put the binary in your `PATH`, e.g.

```sh
curl -L https://github.com/francisdb/vpxtool/releases/download/v0.38.0/vpxtool-linux-x86_64-v0.38.0.tar.gz | tar xz -C ~/.local/bin
```

(`aarch64` builds are there too; or `cargo install vpxtool`.)

Download the official **WoVP Patcher** (link on the WoVP site / Discord) and unpack it anywhere.

### Without git (e.g. Batocera)

```sh
curl -fsSL https://raw.githubusercontent.com/shelobik/pinproof/main/install.sh | bash -s -- --with-vpxtool
```

Installs `pinproof` (and with `--with-vpxtool` also vpxtool) to `~/.local/bin` — on Batocera to `/userdata/system/bin`,
which survives updates — creates a config template and asks for your API key (checked right away). Needs Python 3.11+
and curl or wget. Run it again to update; your config is kept. Options: `--dir DIR`, `--ref TAG`, `--api-key KEY`.

## Configure

`~/.config/pinproof/config.toml` (keep it private, it holds your API key — `chmod 600`):

```toml
api_key = "your key from https://worldofvirtualpinball.com/en/challenge/settings?tab=general"
patcher = "~/Downloads/WoVP_Patcher 1.2.0"     # folder of the official patcher (contains bin/wovp_script.vbs)
vpxtool = "vpxtool"                            # path, if not in PATH
log_dir = "~/vpin_logs"                        # where the telemetry writes its logs
# screenshot_command = ""                     # empty: whole desktop with the first tool found (spectacle, grim,
                                               # gnome-screenshot, scrot, maim, import); or e.g. "grim {file}" (full paths)
# temp_dir = ""                                # where tables are unpacked while patching (default: next to the table)
# backup_suffix = ".bak"                       # `patch` keeps the original as TABLE.vpx + this
# keep_days = 14                               # `logs clean`: delete logs older than this
# keep_submitted_days = 60                     # ... and logs of submitted scores older than this
# gamename_fix = true                          # see "Linux VPX crash" below
# on_screenshot = ""                           # `submit` hooks: commands run at each step, {message} = the text,
# on_success = ""                              # e.g. "notify-send pinproof {message}" or a message on a cabinet screen
# on_error = ""
```

`PINPROOF_API_KEY` in the environment overrides `api_key`.

## Use

**Patch** the tables of the current challenges (only once per table; the original is kept as `TABLE.vpx.bak`,
see `backup_suffix`):

```sh
pinproof challenges                 # which tables, which versions
pinproof patch -n "Some Table.vpx"  # dry run: build and verify, change nothing
pinproof patch "Some Table.vpx"
```

Same as the official patcher: two timers cloned from the table's first timer (`WoVP_Timer` 1000 ms,
`WoVP_FastTimer` 50 ms) and the telemetry script appended to the table script. If the table has a sidecar script
(`TABLE.vbs` next to the `.vpx`, which VPX runs instead of the embedded one), the script is appended there too.
`WoVP_LogDir` is set to `log_dir`. A table that is already patched is left alone; to re-patch, restore the backup.

**Submit** at the end of a game, while the final score is on screen:

```sh
pinproof submit            # the table VPX is running now, screenshot of the whole desktop
pinproof submit -n         # dry run: find the challenge and take the screenshot, send nothing
pinproof submit --image shot.png "Some Table.vpx"
```

Bind `pinproof submit` to a hotkey or a cabinet button. The score is sent as `0` and read from the screenshot by WoVP
(like VPin Studio does); every score is approved by the WoVP admins. Give `--score N` to send the number yourself.
On alphanumeric displays wait until your score is shown — the display cycles through other texts after a game.

The challenge is found by, in order: `--challenge ID`, `--vps ID`, the VPS id in a [VPinFE](https://github.com/superhac/vpinfe)
`.info` file next to the table, the challenge's script keywords (all must appear in the table file name or script),
the table name.

**Logs**: the telemetry writes `WoVP_<rom>_<start time>.log` into `log_dir` (one file per table start, every 5 s).
There is no score in the name, so `submit` keeps a hard link of the table's newest log in `log_dir/submitted/` and
adds a line to `log_dir/submitted.tsv`. Send a log only when the admins ask for it or your score is above their
threshold. Clean up old logs with `pinproof logs clean` (e.g. weekly from cron or a systemd timer).

## Linux VPX crash (`gamename_fix`)

In the Linux builds of VPX 10.8.1 (up to at least rev. 5436), the B2SLegacy plugin treats a script *read* of
`Controller.GameName` as a write and VPX crashes (segfault) on the first telemetry tick. Fixed upstream on 2026-10-05
("Fix crash on romless B2S tables from uninitialized script call arguments"), not in a release yet. With
`gamename_fix = true` (default) the patch reads the table's `cGameName` constant instead — the same ROM name. Set it
to `false` once your VPX has the fix.

## Notes

- Telemetry works on ROM (PinMAME) tables only, as with the official patcher.
- Tested with VPX 10.8.1 Linux (BGFX), vpxtool 0.34.8 and 0.38.0, WoVP Patcher 1.2.0.
- API: WHSC API Integration Guide v1.0 (WoVP). Made with the WoVP admins' agreement; not an official WoVP tool.

## License

MIT — see [LICENSE](LICENSE). The WoVP telemetry script belongs to WoVP and is not distributed here.
