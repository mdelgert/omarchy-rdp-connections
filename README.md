# RDP Connections

An [Omarchy](https://omarchy.org) Quattro bar plugin for saving, editing, and
launching RDP connections through `sdl-freerdp3`, with working Hyprland
multi-monitor fullscreen.

Click **RDP** in the bar and Omarchy's own menu offers **Connect**, **New
connection**, **Edit connection**, and **Remove connection**. Adding one asks
for a server, a username, and a password — nothing else. After installing the
plugin, it needs no terminal commands.

- Plugin ID: `io.github.mdelgert.rdp-connections`
- Kind: `bar-widget`

## Dependencies

**None to install.** The plugin uses only what an Omarchy machine already has:

| Command                                | Comes from            |
| -------------------------------------- | --------------------- |
| `sdl-freerdp3`                         | `freerdp`             |
| `secret-tool`                          | `libsecret`           |
| `jq`, `hyprctl`, `notify-send`, `setsid`, `flock` | base desktop |
| `omarchy-menu-select`, `omarchy-menu-input` | Omarchy itself   |

The UI is Omarchy's own menu, so there is no `fuzzel`, `rofi`, or `walker`
dependency. If you want to confirm before installing:

```sh
for c in sdl-freerdp3 secret-tool jq hyprctl notify-send setsid flock \
         omarchy-menu-select omarchy-menu-input; do
  printf '%-22s %s\n' "$c" "$(command -v "$c" || echo MISSING)"
done
```

Everything should report a path. On the off chance `freerdp` or `libsecret` is
absent, `sudo pacman -S --needed freerdp libsecret` fills the gap.

The plugin ships no install hooks and never installs anything itself; a missing
command is reported in a notification when you click **RDP**.

## Install

### From GitHub

```sh
omarchy plugin add https://github.com/mdelgert/omarchy-rdp-connections.git --enable
```

### From a local clone

```sh
plugin_dir="$HOME/.config/omarchy/plugins/io.github.mdelgert.rdp-connections"
mkdir -p "$plugin_dir"
cp -aT . "$plugin_dir"
chmod 755 "$plugin_dir/scripts/rdp-menu" "$plugin_dir/scripts/rdp-launch"
omarchy plugin validate "$plugin_dir"
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.mdelgert.rdp-connections
```

To move the button: `omarchy bar move io.github.mdelgert.rdp-connections --section center`.
To uninstall: `omarchy plugin remove io.github.mdelgert.rdp-connections`.

## How the UI is put together

| File               | Role                                                     |
| ------------------ | -------------------------------------------------------- |
| `BarWidget.qml`    | the **RDP** button; runs the manager and relays its prompts |
| `Panel.qml`        | the masked password prompt, a centred overlay             |
| `scripts/rdp-menu` | the manager: menus, keyring writes, index bookkeeping     |
| `scripts/rdp-launch` | resolves Hyprland and starts `sdl-freerdp3`             |

Pickers and text entry go through `omarchy-menu-select` and
`omarchy-menu-input`, which summon Omarchy's first-party `omarchy.menu` plugin.

The password is the one prompt that cannot: `omarchy-menu-input` renders what
you type in the clear, and both helpers return their answer by writing it to a
temp file and reading it back. So `rdp-menu` runs as a child of the bar widget
rather than detached, and the two talk over its pipes — when it needs a
password it writes `password\t<prompt>` on stdout and blocks, `Panel.qml` opens
a masked field, and the answer comes back on stdin as `ok:<password>` (or
`cancel`). This is the same approach as Omarchy's built-in Wi-Fi passphrase
prompt, whose `Process` carries the secret over stdin with the note *"The
password goes over stdin, never argv."*

The prompt itself is built like the shell's polkit agent and lock screen — a
full-screen overlay with the card centred and exclusive keyboard focus — rather
than as a bar panel hanging off the **RDP** button. The three prompts before it
are Omarchy's menu card in the middle of the screen, so a panel pinned to the
corner would move the flow out from under you halfway through. Clicking off the
card refocuses it rather than dismissing; Escape cancels.

Run straight from a terminal there is no widget on the other end of the pipe,
so the script falls back to a silent `read -rs` and stays directly testable.

## Security model

**Secrets never touch the filesystem.** Server, username, and password are held
by the Secret Service keyring under a namespaced attribute set:

| Attribute     | Value                               |
| ------------- | ----------------------------------- |
| `application` | `io.github.mdelgert.omarchy-rdp`    |
| `connection`  | opaque random id, e.g. `conn-9f3a…` |
| `field`       | `server`, `username`, or `password` |

Inspect them yourself:

```sh
secret-tool search --all application io.github.mdelgert.omarchy-rdp
```

The only thing written to disk is a list of opaque ids at
`${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-rdp-connections/connections.json`
(mode `600`, in a `700` directory):

```json
{ "connections": [ { "id": "conn-9f3a…" } ] }
```

A connection is labelled by its server, and that label is read back out of the
keyring when the menu is drawn rather than cached in the file — so the hostname
never lands on disk. No host, username, or password is written to that file, to
a temp file, to a log, or into a desktop notification: notifications say
"Connection saved" rather than naming the host, because a notification outlives
the moment and can sit in a shared history. Values are passed to `secret-tool`
on **stdin**, never as arguments.

Editing changes one field at a time — **Server**, **Username**, or **Password**
— rather than walking every field, because
`omarchy-menu-input` cannot prefill: showing you the current host or username
would mean putting it in the helper's world-readable `/proc/<pid>/cmdline`.

Two connections may legitimately point at the same host. A repeat gets a counter
appended for display only — `d1`, `d1 (2)` — which is enough to tell the rows
apart and to map a choice back to exactly one id, without a second name to
maintain.

Only one manager runs at a time, enforced with `flock` on
`.menu.lock` in the state directory. The bar instantiates the widget once per
monitor, so two menus could otherwise be open at once — and since saving means
read, modify, write of the index, the second one to save would silently drop
whatever the first had added. A second attempt reports "A connection menu is
already open" instead. The launched RDP client is given the lock descriptor
closed (`9>&-`), so a live session does not block reopening the menu.

### The password is *not* exposed in the process list

FreeRDP's usual `/p:<password>` puts the password in `argv`, and
`/proc/<pid>/cmdline` is world-readable, so any local user can read it for as
long as the session runs.

FreeRDP 3 offers two ways out, and this plugin uses the stronger one:

- `/from-stdin` — prompts for credentials on stdin, but only for fields that
  were not supplied, and the prompt timing depends on `force` vs. server
  request.
- `/args-from:stdin` — reads the **entire** command line from stdin, one
  argument per line. It cannot be combined with any other argument.

`scripts/rdp-launch` builds the argument vector in shell variables and pipes it
in with the `printf` builtin, so the credentials go straight down a pipe from
the launcher process and are never another process's arguments:

```sh
printf '%s\n' "${args[@]}" | exec sdl-freerdp3 /args-from:stdin
```

Verified on FreeRDP 3.30.0 — the running client's full command line is:

```
sdl-freerdp3 /args-from:stdin
```

Residual exposure: the password is still in the FreeRDP process's heap, as it
must be for any client, and any process able to read that memory (same user, or
root) can recover it. `/proc/<pid>/environ` is owner-readable only, so the
exported `HYPRLAND_INSTANCE_SIGNATURE` / `WAYLAND_DISPLAY` / `FREERDP_WLROOTS_HACK`
values are not world-visible either.

### The `/cert:ignore` tradeoff

`/cert:ignore` accepts the server's TLS certificate without validating it and
without prompting. That removes the certificate warning on self-signed hosts —
the reason it is the common default for lab and internal machines — but it also
**removes protection against an active man-in-the-middle**: an attacker who can
redirect your traffic can present any certificate and silently relay the
session, including your password and keystrokes.

Use it only on networks you trust. On an untrusted network, edit
`scripts/rdp-launch` and replace `/cert:ignore` with `/cert:tofu` (trust on
first use, like SSH) or drop the flag entirely so FreeRDP prompts and pins.

This is carried over from the launch command the plugin was built to reproduce;
it is a deliberate, documented default, not an oversight.

## How launching works

`scripts/rdp-launch` reproduces the known-good invocation:

1. Resolve the newest Hyprland instance with `hyprctl instances -j | jq`, and
   export `HYPRLAND_INSTANCE_SIGNATURE` and `WAYLAND_DISPLAY` from it. The bar's
   own environment can point at a stale compositor after a Hyprland restart.
2. Export `FREERDP_WLROOTS_HACK=force`, without which `/multimon` fullscreen
   lands on a single output.
3. Launch `sdl-freerdp3` with `-grab-keyboard /sound /microphone /clipboard
   /cert:ignore /dvc:rdpecam +f /multimon`.

It is started with `setsid` so the RDP session outlives both the menu and a
reload of the shell. Incomplete credentials — including a keyring that is
locked or unavailable — abort with a desktop notification instead of launching.

## Development

Run the manager directly, without installing. Menus still come from the running
shell; the password prompt falls back to a silent terminal read:

```sh
./scripts/rdp-menu
```

Validation that runs anywhere:

```sh
jq empty manifest.json
bash -n scripts/rdp-menu scripts/rdp-launch
shellcheck scripts/rdp-menu scripts/rdp-launch
```

Validation that needs an Omarchy host:

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml
```

If `qmllint` reports that `qs.Ui` and `qs.Commons` cannot be imported, point it
at a directory containing a `qs` entry for the shell instead — Quickshell
exposes the shell root as the module `qs`:

```sh
mkdir -p /tmp/qsimports && ln -sfn "$OMARCHY_PATH/shell" /tmp/qsimports/qs
qmllint -I /tmp/qsimports BarWidget.qml Panel.qml
```

A few warnings are expected and are qmllint limitations rather than defects:
`Member "x" not found on type "QObject"` (`Loader.item` is untyped, and
`Style.spacing` / `Style.font` are QtObject groups) and `Type PanelWindow is not
creatable`. Omarchy's own polkit agent and panels report exactly the same ones.

### Reloading QML changes

The shell only ever reads `~/.config/omarchy/plugins/<id>/`, never your
checkout, so editing `BarWidget.qml` or `Panel.qml` here does nothing on its
own. Install and reload in one step:

```sh
scripts/dev-install            # copy + restart the shell
scripts/dev-install --enable   # ...and add it to the bar if it is not there
scripts/dev-install --no-restart

scripts/dev-uninstall          # take it off the bar, delete the installed copy, reload
scripts/dev-uninstall --yes    # skip the confirmation prompt
```

`dev-uninstall` is the counterpart, for testing a clean-slate install: it
disables the plugin, deletes `~/.config/omarchy/plugins/<id>/`, and restarts the
shell. Your checkout is never touched. It refuses to delete a directory whose
`manifest.json` carries a different id, and refuses outright if it finds a
`.git` inside (that would be a real clone, not a dev install — use
`omarchy plugin remove` for those, which keeps a backup). State outside the
plugin directory, such as saved credentials, is deliberately left alone.

It reads the id from `manifest.json`, copies only what the plugin needs
(`manifest.json`, `*.qml`, `*.js`, `README.md`, `LICENSE`, `scripts/`, `docs/`,
`assets/` — so `.git` and `PROMPT.md` stay out of the plugins dir), mirrors each
file's executable bit, and runs `omarchy plugin validate` on the working tree
*before* touching the installed copy, so a broken manifest leaves the running
plugin alone.

**Why a full shell restart rather than the file watcher?** Saving under
`~/.config/omarchy/plugins/` does fire the shell's "plugin changed, reloading"
watcher, but that does not re-instantiate a bar widget the bar is already
holding: `BarWidget.qml` is mounted once per bar, and its bindings and
`IpcHandler` are fixed at instantiation. `omarchy-shell shell rescanPlugins`
does not pick those up either. Measured against a changed bar label:

| Action | Reload event | Change actually applied |
|--------|--------------|-------------------------|
| Save in the repo only | no | no |
| Copy into the plugins dir | yes | no |
| `omarchy-shell shell rescanPlugins` | — | no |
| `omarchy-restart-shell` | — | **yes** |

Two things that will otherwise waste your time:

- Use plain `cp`, never `cp -a`. `-a` preserves mtimes, and the watcher never
  notices a file whose timestamp did not move. (The `cp -aT .` under
  [From a local clone](#from-a-local-clone) is fine for a first install, which
  ends in an explicit `rescanPlugins`, but it is not a reload loop.)
- Do **not** symlink the plugin directory at your checkout. The shell will load
  it, but the file watcher does not follow symlinks and
  `omarchy plugin validate` rejects it outright with
  `symlinks are not allowed inside a plugin folder`.

Clearing `~/.cache/quickshell/qmlcache` is not necessary; the restart is
sufficient.

## Keyboard shortcut

The bar button is the primary entry point, but the widget also registers an IPC
handler, so the manager can be opened without touching the bar:

```sh
omarchy-shell io.github.mdelgert.rdp-connections open
```

To bind that to a key, add it to `~/.config/hypr/bindings.lua`:

```lua
-- RDP plugin
o.bind("SUPER + R", "RDP connections", "omarchy-shell io.github.mdelgert.rdp-connections open")
```

Hyprland picks the change up on save; no restart is needed. Confirm it landed
with `hyprctl binds | grep -B8 "RDP connections"` — the entry should read
`modmask: 64` (SUPER on its own) and `key: R`.

`SUPER + R` is free on a stock Omarchy install. The three reminder shortcuts
also use `R`, but each of them adds Ctrl (`modmask` 68, 76, and 69), so they do
not collide. If you would rather use a different key, list what is already taken
with:

```sh
omarchy menu keybindings --print
```

Note that the prompt opens on whichever monitor the shell puts the overlay on,
which is not necessarily the one holding keyboard focus. Clicking the bar button
instead always uses the bar you clicked.

## Scope of v0.1

One launch profile for every connection, matching the command above.
Per-connection resolution, gateways, `/drive:` redirection, and certificate
policy are not configurable yet; edit `scripts/rdp-launch` if you need them
today.

## License

Icon provided by [Nerdfonts](https://www.nerdfonts.com/cheat-sheet)

MIT — see [LICENSE](LICENSE).
