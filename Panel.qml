import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// The one prompt that cannot be Omarchy's own menu.
//
// omarchy-menu-input renders what you type and hands the answer back through
// a temp file, and a password may do neither, so the manager script asks the
// widget for this one instead.
//
// It is built the way the shell's own polkit agent and lock screen are built
// — a centred card on a full-screen overlay that takes keyboard focus — and
// deliberately not as a KeyboardPanel hanging off the bar button. The three
// prompts before it are the omarchy.menu card in the middle of the screen, so
// a panel pinned to the top-right corner would move the flow out from under
// the user halfway through.
Item {
  id: root

  property string prompt: "Password"

  // Set between ask() and the answer. It guards against answering twice, and
  // against never answering at all: the script is blocked on a read, so a
  // dismissed prompt still owes it a cancel.
  property bool pending: false

  signal submitted(string value)
  signal cancelled

  function ask(promptText) {
    root.prompt = promptText && promptText.length > 0 ? promptText : "Password"
    field.text = ""
    root.pending = true
  }

  function respond(accepted) {
    if (!root.pending)
      return
    root.pending = false
    var value = field.text
    field.text = ""
    if (accepted)
      root.submitted(value)
    else
      root.cancelled()
  }

  // The script has gone away, so there is nobody left to answer. Drop the
  // prompt without emitting, rather than firing a cancel into a dead pipe.
  function abort() {
    root.pending = false
    field.text = ""
  }

  PanelWindow {
    id: window
    visible: root.pending
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-rdp-password"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Color.background, 0.5)
    }

    // Clicking off the card refocuses rather than dismisses: losing a typed
    // password to a stray click is worse than having to press Escape.
    MouseArea {
      anchors.fill: parent
      onClicked: field.forceActiveFocus()
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(420), window.width - Style.gapsOut * 2)
      height: column.implicitHeight + Style.spacing.panelPadding * 2
      radius: Style.cornerRadius
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      Column {
        id: column
        anchors.centerIn: parent
        width: card.width - Style.spacing.panelPadding * 2
        spacing: Style.spacing.rowGap

        Text {
          width: parent.width
          text: root.prompt
          color: Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        TextField {
          id: field
          width: parent.width
          password: true
          placeholderText: "Password"
          foreground: Color.popups.text
          onAccepted: root.respond(true)
          Keys.onEscapePressed: root.respond(false)
          onVisibleChanged: if (visible) Qt.callLater(forceActiveFocus)
        }
      }
    }
  }

  // The overlay only exists while a prompt is up, so focus has to be taken
  // after the window is mapped rather than when the field is constructed.
  onPendingChanged: if (root.pending) Qt.callLater(function () { field.forceActiveFocus() })
}
