import QtQuick
import qs.Commons

// One app on the taskbar: icon, hover plate and the running/focused pill.
Item {
  id: btn

  required property string key
  required property int index
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

  // Drag-to-reorder (pinned apps). pointerX and grabOffset are in the
  // parent Row's coordinates.
  readonly property int dragThreshold: 8
  property bool dragging: false
  property bool dragged: false
  property real pressX: 0
  property real pointerX: 0
  property real grabOffset: 0

  function dragTo(x) {
    pointerX = x
    var slot = width + parent.spacing
    var first = dock.config.showStart ? slot : 0
    var center = pointerX - grabOffset + width / 2
    var target = Math.floor((center - first) / slot)
    target = Math.max(0, Math.min(dock.pinnedCount() - 1, target))
    dock.moveApp(index, target)
  }

  width: dock.buttonSize
  height: dock.buttonSize
  opacity: 0
  scale: 0.6
  z: dragging ? 1 : 0

  // Reads the live Row-assigned x, so the icon stays under the pointer
  // while a reorder relayouts the row beneath it.
  transform: Translate {
    x: btn.dragging ? btn.pointerX - btn.grabOffset - btn.x : 0
    Behavior on x {
      enabled: !btn.dragging
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
  }

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
    color: btn.dragging ? Util.alpha(btn.dock.text, 0.14)
      : mouse.pressed ? Util.alpha(btn.dock.text, 0.05)
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
    scale: btn.dragging ? 1.08 : mouse.pressed ? 0.82 : 1

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

    onEntered: if (!btn.dragging) btn.bar.buttonEntered(btn)
    onExited: btn.bar.buttonExited(btn)
    onPressed: function(event) {
      btn.dragged = false
      btn.pressX = mapToItem(btn.parent, event.x, event.y).x
    }
    onPositionChanged: function(event) {
      if (!(pressedButtons & Qt.LeftButton) || !btn.info || !btn.info.pinned) return
      var x = mapToItem(btn.parent, event.x, event.y).x
      if (!btn.dragging) {
        if (Math.abs(x - btn.pressX) < btn.dragThreshold) return
        btn.grabOffset = btn.pressX - btn.x
        btn.dragging = true
        btn.dragged = true
        btn.bar.dismissPopups()
      }
      btn.dragTo(x)
    }
    onReleased: {
      if (!btn.dragging) return
      btn.dragging = false
      btn.dock.commitOrder()
    }
    onCanceled: btn.dragging = false
    onClicked: function(event) {
      if (btn.dragged) return
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
