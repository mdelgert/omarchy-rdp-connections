import QtQuick
import qs.Commons
import qs.Ui

// The one prompt that cannot be Omarchy's own menu.
//
// omarchy-menu-input renders what you type and hands the answer back through
// a temp file, and a password may do neither, so the manager script asks the
// widget for this one instead. It is the same shape as the shell's built-in
// Wi-Fi passphrase prompt: a masked field whose value goes straight out over
// the script's stdin and is cleared the moment it has been handed over.
//
// BarWidget.qml owns the bar label and hands this panel the button to anchor
// against.
Panel {
  id: root
  moduleName: "io.github.mdelgert.rdp-connections"
  manageIpc: false

  property var anchorItem: null

  // The bar tracks the widget mounted in its slot — BarWidget.qml — not this
  // nested panel, so the popout coordinator has to be given that identity.
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property string prompt: "Password"

  // Set between ask() and the answer. It guards against answering twice, and
  // against never answering at all: the script is blocked on a read, so a
  // panel dismissed by clicking away still owes it a cancel.
  property bool pending: false

  signal submitted(string value)
  signal cancelled

  function ask(promptText) {
    root.prompt = promptText && promptText.length > 0 ? promptText : "Password"
    field.text = ""
    root.pending = true
    root.open()
    Qt.callLater(function () { field.forceActiveFocus() })
  }

  function respond(accepted) {
    if (!root.pending)
      return
    root.pending = false
    var value = field.text
    field.text = ""
    root.close()
    if (accepted)
      root.submitted(value)
    else
      root.cancelled()
  }

  onOpenedChanged: if (!root.opened) root.respond(false)

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: field
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.spacing.rowGap

      Text {
        width: parent.width
        text: root.prompt
        color: root.barForeground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      TextField {
        id: field
        width: parent.width
        password: true
        placeholderText: "Password"
        foreground: root.barForeground
        onAccepted: root.respond(true)
        Keys.onEscapePressed: root.respond(false)
      }
    }
  }
}
