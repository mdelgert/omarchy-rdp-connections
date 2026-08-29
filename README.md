# RDP Connections

RDP Connections is an Omarchy Quattro bar widget for creating, editing, removing, and launching saved remote-desktop connections with the SDL FreeRDP client. It is designed for Hyprland multi-monitor fullscreen sessions.

## Use

Enable the plugin in Omarchy. Select **RDP** from the bar, then choose **Connect**, **New connection**, **Edit connection**, or **Remove connection**. The connection flow asks only for a server, user name, and password.

## Screenshots

The RDP entry appears in the right side of the Omarchy bar.

![RDP entry in the Omarchy bar](docs/images/bar-button.png)

Selecting it opens the connection menu.

![RDP connection menu](docs/images/menu.png)

Creating a connection collects the server and user name, followed by a masked password field.

| Server | User name |
| --- | --- |
| ![Server field](docs/images/new-server.png) | ![User name field](docs/images/new-username.png) |

![Masked password field](docs/images/new-password.png)

The saved confirmation does not include the connection host.

![Saved connection confirmation](docs/images/saved.png)

Existing connections can be selected for connection or editing.

| Connect | Edit |
| --- | --- |
| ![Connection selection](docs/images/connect.png) | ![Connection edit selection](docs/images/edit.png) |

Removing a connection starts with a confirmation screen.

![Connection removal confirmation](docs/images/remove.png)

The host names shown in these screenshots are documentation-only examples.

## Requirements

This plugin requires Omarchy Quattro, a Hyprland session, FreeRDP 3 with the SDL client, Secret Service support, `jq`, desktop notifications, and the standard user-session utilities supplied by Omarchy. Install these prerequisites using your distribution's normal software-management method before enabling the plugin.

The plugin does not fetch, build, or add software. It operates only within the signed-in user's graphical session.

## Installation

In Omarchy's plugin manager, add this repository and enable **RDP Connections**:

https://github.com/mdelgert/omarchy-rdp-connections

## Data handling

Connection server, user name, and password are stored in the user's Secret Service keyring. The plugin's local state contains only a connection label and an opaque identifier. It does not edit Hyprland, Omarchy, shell, or bar configuration files.

The RDP client is configured for the working multi-monitor connection profile, including fullscreen, audio, microphone, clipboard, camera, keyboard capture, and certificate-ignore behavior. Certificate-ignore behavior bypasses server-certificate validation; connect only to hosts you trust.

## Removal

Remove every saved connection from the RDP menu first if its keyring entries should also be deleted. Then remove **RDP Connections** through Omarchy's plugin manager.

## License

MIT
