Paste this into the coding agent:

Build a production-quality starter repository named `omarchy-rdp-connections` for an Omarchy Quattro plugin.

Goal: provide a simple Omarchy bar UI for users to create, manage, and launch saved RDP connections using `sdl-freerdp3`. It must support Hyprland multi-monitor RDP using this proven launch behavior:

```sh
env $(hyprctl instances -j | jq -r 'sort_by(.time)|last|"HYPRLAND_INSTANCE_SIGNATURE=\(.instance) WAYLAND_DISPLAY=\(.wl_socket)"') \
  FREERDP_WLROOTS_HACK=force \
  sdl-freerdp3 /v:d1 /u:mdelgert "/p:$(secret-tool lookup name masterpassword)" \
  -grab-keyboard /sound /microphone /clipboard /cert:ignore /dvc:rdpecam +f /multimon
```

Use these references as the source of truth for the Omarchy plugin contract:

* [https://omarchyplugins.com/develop.html](https://omarchyplugins.com/develop.html)
* [https://github.com/basecamp/omarchy/blob/quattro/shell/README.md](https://github.com/basecamp/omarchy/blob/quattro/shell/README.md)

Requirements:

1. Create a valid third-party Omarchy `bar-widget` plugin:

   * Plugin ID: `io.github.mdelgert.rdp-connections`
   * Display name: `RDP Connections`
   * A bar button labeled `RDP`
   * Clicking the button opens the connection-management UI.

2. Keep the v0.1 UI intentionally simple:

   * Use `fuzzel` as the UI launched by the bar widget.
   * Actions: Connect, New connection, Edit connection, Remove connection.
   * The user should need no terminal commands after initial dependency installation and plugin installation.
   * Do not attempt to install packages or execute install hooks automatically; document the one-time dependencies instead.

3. Store credentials securely:

   * Store server, username, and password with `secret-tool` / Secret Service.
   * Use a namespaced attribute model, such as:

     * `application=io.github.mdelgert.omarchy-rdp`
     * `connection=<opaque-id>`
     * `field=server|username|password`
   * Store only a connection display name and opaque ID in a local JSON index under `$XDG_STATE_HOME` (or `~/.local/state`).
   * Never write server, username, or password to JSON files, logs, shell history, or notifications.
   * Use unique connection names or implement a safe disambiguation mechanism.

4. Launch correctly:

   * Resolve the newest Hyprland instance with `hyprctl instances -j` and `jq`.
   * Export `HYPRLAND_INSTANCE_SIGNATURE` and `WAYLAND_DISPLAY`.
   * Set `FREERDP_WLROOTS_HACK=force`.
   * Launch `sdl-freerdp3` with:
     `-grab-keyboard /sound /microphone /clipboard /cert:ignore /dvc:rdpecam +f /multimon`
   * Quote all shell values safely and reject incomplete credentials with a graphical notification.
   * Investigate whether SDL FreeRDP supports a password-via-stdin mechanism. If it does, use it. If not, document clearly that FreeRDP receives the password as an argument at launch and may briefly expose it to other local processes.

5. Repository contents:

   * `manifest.json`
   * `BarWidget.qml`
   * `scripts/rdp-menu`
   * `scripts/rdp-launch`
   * `README.md`
   * `LICENSE` (MIT)
   * `.gitignore`
   * Ensure shell scripts are executable in Git (`100755`).

6. README:

   * Explain the security model and the `/cert:ignore` tradeoff.
   * List Arch dependencies: `freerdp`, `libsecret`, `fuzzel`, `jq`.
   * Include exact local-install commands.
   * Include exact GitHub-install command:

     ```sh
     omarchy plugin add https://github.com/mdelgert/omarchy-rdp-connections.git --enable
     ```
   * Include a direct development test command:

     ```sh
     ./scripts/rdp-menu
     ```

7. Validation:

   * Run `jq empty manifest.json`.
   * Run `bash -n` on both scripts.
   * Run ShellCheck if installed.
   * Document host-only checks:

     ```sh
     omarchy plugin validate .
     qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml
     ```
   * Do not claim QML runtime validation succeeded unless running on an actual Omarchy system.

Work carefully in the existing repository. Preserve unrelated user changes. Finish by summarizing the files created, validation results, any unresolved FreeRDP password-handling limitation, and the exact local installation command sequence.
