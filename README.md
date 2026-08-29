# RDP Connections for Omarchy

A small Omarchy bar plugin for creating, selecting, editing, deleting, and launching RDP connections through `sdl-freerdp3` with Hyprland multi-monitor support.

## What it stores

The connection display name and opaque ID are stored locally in:

`~/.local/state/omarchy-rdp-connections/connections.json`

Server, username, and password are stored in the logged-in user's Secret Service keyring using `secret-tool`; they are never written to that JSON file. The RDP password is necessarily supplied to `sdl-freerdp3` at launch, as in the original working command. It can therefore be briefly visible to other local processes through process arguments. This is a FreeRDP invocation limitation to resolve before calling the project production-ready.

## Dependencies

- `freerdp` (`sdl-freerdp3`)
- `libsecret` (`secret-tool`)
- `fuzzel`
- `jq`
- `hyprland` (`hyprctl`)

On Arch:

```sh
sudo pacman -S freerdp libsecret fuzzel jq
```

## Install locally

```sh
plugin_dir="$HOME/.config/omarchy/plugins/io.github.mdelgert.rdp-connections"
mkdir -p "$plugin_dir"
cp -a . "$plugin_dir"
chmod 700 "$plugin_dir/scripts/rdp-menu" "$plugin_dir/scripts/rdp-launch"
omarchy plugin validate "$plugin_dir"
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.mdelgert.rdp-connections
```

Click the **RDP** bar item. The fuzzel menu offers **New connection**, **Connect**, **Edit**, and **Remove**.

## Install from GitHub

After publishing this directory as the repository root:

```sh
omarchy plugin add https://github.com/mdelgert/omarchy-rdp-connections.git --enable
```

## Validate while developing

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml
```

## Current deliberate constraints

- Uses the exact SDL FreeRDP flags from the supplied successful command, including `/multimon`.
- One fixed launch profile for all connections. Per-connection options, gateways, resolution, and certificate policy are future work.
- The UI uses fuzzel (native to the Omarchy desktop workflow) rather than a larger QML editor panel; this keeps v0.1 low-risk and easy to audit.

## License

MIT
