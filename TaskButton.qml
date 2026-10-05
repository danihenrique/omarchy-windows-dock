import QtQuick
import qs.Commons

// One app on the taskbar: icon, hover plate and the running/focused pill.
Item {
  id: btn

  required property string key
  required property var dock
  required property var bar

  readonly property var info: dock.appData[key] || null
  readonly property var windows: info ? info.windows : []
  readonly property bool running: windows.length > 0
  readonly property bool active: {
    for (var i = 0; i < windows.length; i++) {
      if (windows[i] && windows[i].activated) return true
    }
    return false
  }
  property real bump: 0

  width: dock.buttonSize
  height: dock.buttonSize
  opacity: 0
  scale: 0.6

  // Pop-in. Lives here rather than in the Row's add transition, which the
  // positioner can interrupt and leave the button stuck invisible.
  ParallelAnimation {
    running: true
    NumberAnimation { target: btn; property: "opacity"; to: 1; duration: 180 }
    NumberAnimation { target: btn; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack }
  }

  Rectangle {
    anchors.fill: parent
    radius: 6
    color: mouse.pressed ? Util.alpha(btn.dock.text, 0.05)
      : mouse.containsMouse ? Util.alpha(btn.dock.text, 0.1)
      : btn.active ? Util.alpha(btn.dock.text, 0.07)
      : "transparent"
    border.width: 1
    border.color: (btn.active || mouse.containsMouse) ? Util.alpha(btn.dock.text, 0.06) : "transparent"

    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Image {
    id: icon
    anchors.centerIn: parent
    anchors.verticalCenterOffset: btn.bump - 1
    width: btn.dock.iconSize
    height: btn.dock.iconSize
    sourceSize: Qt.size(width * 2, height * 2)
    source: btn.dock.iconFor(btn.info)
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    scale: mouse.pressed ? 0.82 : 1

    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
  }

  // Short grey pill = running, wide accent pill = focused.
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    width: !btn.running ? 0 : (btn.active ? 16 : 6)
    height: 3
    radius: 1.5
    color: btn.active ? btn.dock.accent : Util.alpha(btn.dock.text, 0.55)
    opacity: btn.running ? 1 : 0

    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  // Launch feedback: the icon dips and springs back.
  SequentialAnimation {
    id: launchBump
    NumberAnimation { target: btn; property: "bump"; to: 4; duration: 90; easing.type: Easing.OutQuad }
    NumberAnimation { target: btn; property: "bump"; to: -3; duration: 130; easing.type: Easing.OutQuad }
    NumberAnimation { target: btn; property: "bump"; to: 0; duration: 160; easing.type: Easing.OutBounce }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

    onEntered: btn.bar.buttonEntered(btn)
    onExited: btn.bar.buttonExited(btn)
    onClicked: function(event) {
      if (event.button === Qt.RightButton) {
        btn.bar.openAppMenu(btn)
        return
      }
      btn.bar.dismissPopups()
      if (event.button === Qt.MiddleButton || !btn.running) {
        launchBump.restart()
        btn.dock.launch(btn.info)
      } else {
        btn.dock.activate(btn.info)
      }
    }
  }
}
