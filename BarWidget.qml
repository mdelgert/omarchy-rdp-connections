import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// RDP Connections — a bar button that opens the connection manager.
//
// The manager itself is scripts/rdp-menu, driven by Omarchy's own menu
// (omarchy-menu-select / omarchy-menu-input), so the plugin adds no UI
// dependency. The script runs as a child process rather than detached
// because the two talk: when it needs a password it writes a request on
// stdout and blocks, and the masked field in Panel.qml answers on stdin.
// Nothing secret is ever an argument or a temp file.
BarWidget {
  id: root
  moduleName: "io.github.mdelgert.rdp-connections"

  // Qt.resolvedUrl hands back a percent-encoded file:// URL, but the menu has
  // to be launched by path — and a plugin directory may legitimately contain
  // spaces, so the encoding has to come back off.
  readonly property string menuPath: decodeURIComponent(Qt.resolvedUrl("scripts/rdp-menu").toString().replace(/^file:\/\//, ""))

  function openMenu() {
    if (!menu.running)
      menu.running = true
  }

  // Protocol from the script: "password\t<prompt>". Anything else is ignored
  // rather than guessed at, so a future verb cannot make this end answer it.
  function handleLine(line) {
    var text = String(line)
    var tab = text.indexOf("\t")
    if ((tab < 0 ? text : text.substring(0, tab)) !== "password")
      return
    if (panelLoader.item)
      panelLoader.item.ask(tab < 0 ? "" : text.substring(tab + 1))
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target)
      return
    if ("bar" in target)
      target.bar = root.bar
    if ("anchorItem" in target)
      target.anchorItem = button
    if ("hostWidget" in target)
      target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Process {
    id: menu
    command: [root.menuPath]
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function (line) { root.handleLine(line) }
    }
    // A script that died mid-prompt is never going to read the answer, so the
    // field must not be left sitting open waiting to send one.
    onExited: if (panelLoader.item && panelLoader.item.pending) panelLoader.item.close()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  // onExited closes an open panel, which comes back here as a cancel, so both
  // answers have to check there is still a script left to answer.
  Connections {
    target: panelLoader.item

    function onSubmitted(value) {
      if (menu.running)
        menu.write("ok:" + value + "\n")
    }

    function onCancelled() {
      if (menu.running)
        menu.write("cancel\n")
    }
  }

  // On a vertical bar the label is turned on its side, so the slot has to be
  // as tall as the label is wide. Measuring off-item keeps that out of a
  // height -> width -> height binding loop.
  TextMetrics {
    id: labelMetrics
    font.family: button.fontFamily
    font.pixelSize: button.fontSize
    text: button.text
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "RDP"
    tooltipText: "RDP connections"
    textRotation: root.vertical ? 90 : 0
    fixedHeight: root.vertical ? Math.round(labelMetrics.width + Style.spaceReal(8.5) * 2) : -1

    onPressed: function (mouseButton) {
      if (mouseButton === Qt.LeftButton)
        root.openMenu()
    }
  }
}
