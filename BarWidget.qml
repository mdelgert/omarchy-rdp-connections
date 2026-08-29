import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.mdelgert.rdp-connections"

  // This plugin intentionally delegates its compact UI to fuzzel, Omarchy's
  // standard launcher. It keeps the QML surface small and the secret handling
  // in a single auditable shell script.
  readonly property string pluginPath: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: menu
    command: [root.pluginPath + "/scripts/rdp-menu"]
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "RDP"
    tooltipText: "RDP connections"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton && !menu.running) menu.running = true
    }
  }
}
