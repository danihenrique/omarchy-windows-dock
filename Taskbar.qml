import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import "Strings.js" as Strings

// The bar surface for one screen, plus its two popups: the hover preview
// and the right-click menu.
PanelWindow {
  id: win

  required property var modelData
  required property var dock

  readonly property string lang: Qt.locale().name
  readonly property bool centered: dock.floating || dock.config.alignment !== "left"
  readonly property bool revealed: !dock.autoHide || barHover.hovered || edgeHover.hovered || menu.visible || preview.visible || hideDelay.running

  // Hover preview state. hoverButton is what the pointer is over right now,
  // previewButton is what the popup shows; the timers keep the popup alive
  // while the pointer travels from the button up to it.
  property var hoverButton: null
  property var previewButton: null

  // Right-click menu state.
  property var menuInfo: null
  property var menuItems: []
  property real menuCenterX: 0

  screen: modelData
  color: "transparent"
  anchors { left: true; right: true; bottom: true }
  implicitHeight: dock.barHeight + dock.floatMargin
  exclusionMode: dock.autoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
  WlrLayershell.namespace: "win11-dock"
  WlrLayershell.layer: WlrLayer.Top

  // While hidden only a thin strip at the screen edge takes input. With
  // auto-hide the strip stays in the mask when revealed too, so a pointer
  // resting on the edge beside a floating dock doesn't make it flap.
  mask: Region {
    item: win.revealed ? bg : edgeStrip
    Region { item: win.dock.autoHide ? edgeStrip : null }
  }

  function tr(key) { return Strings.tr(key, lang) }

  function popupX(centerX, popupWidth) {
    return Math.round(Math.max(8, Math.min(win.width - popupWidth - 8, centerX - popupWidth / 2)))
  }

  function centerOf(item) {
    return item.mapToItem(bar, item.width / 2, 0).x
  }

  function buttonEntered(button) {
    hoverButton = button
    previewClose.stop()
    if (previewButton) previewButton = button
    else previewOpen.restart()
  }

  function buttonExited(button) {
    if (hoverButton === button) hoverButton = null
    previewOpen.stop()
    previewClose.restart()
  }

  function dismissPopups() {
    previewOpen.stop()
    previewButton = null
    menu.visible = false
  }

  function openMenu(items, info, centerX) {
    dismissPopups()
    menuItems = items
    menuInfo = info
    menuCenterX = centerX
    menu.visible = true
  }

  function openAppMenu(button) {
    var info = button.info
    if (!info) return
    var items = []
    var actions = info.entry ? info.entry.actions : []
    for (var i = 0; i < actions.length; i++) items.push({ id: "action:" + i, text: actions[i].name })
    if (actions.length > 0) items.push({ separator: true })

    items.push({ id: "launch", text: dock.appName(info), icon: dock.iconFor(info) })
    var at = dock.pinIndex(info)
    items.push({ id: at >= 0 ? "unpin" : "pin", text: tr(at >= 0 ? "unpin" : "pin") })
    if (at > 0) items.push({ id: "moveLeft", text: tr("moveLeft") })
    if (at >= 0 && at < dock.config.pinned.length - 1) items.push({ id: "moveRight", text: tr("moveRight") })
    if (info.windows.length > 0) {
      items.push({ separator: true })
      items.push({ id: "close", text: tr(info.windows.length > 1 ? "closeAll" : "close") })
    }
    openMenu(items, info, centerOf(button))
  }

  function openSettingsMenu(centerX) {
    var config = dock.config
    openMenu([
      { id: "autoHide", text: tr("autoHide"), checked: config.autoHide },
      { id: "floating", text: tr("floating"), checked: config.floating },
      { id: "transparent", text: tr("transparent"), checked: config.transparent },
      { id: "alignLeft", text: tr("alignLeft"), checked: config.alignment === "left" },
      { id: "showClock", text: tr("showClock"), checked: config.showClock },
      { id: "showPreviews", text: tr("showPreviews"), checked: config.showPreviews },
      { separator: true },
      { stepper: "barHeight", text: tr("barHeight"), step: 4, min: 36, max: 96 },
      { stepper: "iconSize", text: tr("iconSize"), step: 2, min: 16, max: 80 },
      { separator: true },
      { id: "editConfig", text: tr("editConfig") }
    ], null, centerX)
  }

  // Steppers edit the config in place and leave the menu open.
  function stepSetting(item, direction) {
    var config = dock.config
    var value = config[item.stepper] + direction * item.step
    config[item.stepper] = Math.max(item.min, Math.min(item.max, value))
  }

  function triggerMenu(id) {
    var info = menuInfo
    var config = dock.config
    menu.visible = false
    if (id.indexOf("action:") === 0) info.entry.actions[Number(id.slice(7))].execute()
    else if (id === "launch") dock.launch(info)
    else if (id === "pin") dock.pin(info)
    else if (id === "unpin") dock.unpin(info)
    else if (id === "moveLeft") dock.movePin(info, -1)
    else if (id === "moveRight") dock.movePin(info, 1)
    else if (id === "close") dock.closeAll(info)
    else if (id === "autoHide") config.autoHide = !config.autoHide
    else if (id === "floating") config.floating = !config.floating
    else if (id === "transparent") config.transparent = !config.transparent
    else if (id === "alignLeft") config.alignment = config.alignment === "left" ? "center" : "left"
    else if (id === "showClock") config.showClock = !config.showClock
    else if (id === "showPreviews") config.showPreviews = !config.showPreviews
    else if (id === "editConfig") Quickshell.execDetached(["omarchy-launch-editor", dock.configPath])
  }

  Timer {
    id: previewOpen
    interval: 450
    onTriggered: win.previewButton = win.hoverButton
  }

  Timer {
    id: previewClose
    interval: 250
    onTriggered: if (!win.hoverButton && !previewHover.hovered) win.previewButton = null
  }

  // Keeps the bar up briefly after the pointer leaves, so grazing the edge
  // of an auto-hidden bar doesn't make it flap.
  Timer {
    id: hideDelay
    interval: 500
  }

  Item {
    id: edgeStrip
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: 2

    HoverHandler {
      id: edgeHover
      onHoveredChanged: if (!hovered) hideDelay.restart()
    }
  }

  Item {
    id: bar
    width: parent.width
    height: win.dock.barHeight
    y: win.revealed ? 0 : win.height

    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    HoverHandler {
      id: barHover
      onHoveredChanged: if (!hovered) hideDelay.restart()
    }

    Rectangle {
      id: bg
      x: win.dock.floating ? content.x - 8 : 0
      width: win.dock.floating ? content.width + 16 : parent.width
      height: parent.height
      radius: win.dock.floating ? 12 : 0
      color: win.dock.barColor
      border.width: win.dock.floating && !win.dock.config.transparent ? 1 : 0
      border.color: win.dock.stroke

      // Full-width bar: a single hairline along the top edge.
      Rectangle {
        visible: !win.dock.floating && !win.dock.config.transparent
        width: parent.width
        height: 1
        color: win.dock.stroke
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(event) {
          if (event.button === Qt.RightButton) win.openSettingsMenu(bg.x + event.x)
          else win.dismissPopups()
        }
      }
    }

    Row {
      id: content
      x: win.centered ? Math.round((bar.width - width) / 2) : 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

      move: Transition {
        NumberAnimation { property: "x"; duration: 200; easing.type: Easing.OutCubic }
      }

      // Start
      Item {
        id: start
        visible: win.dock.config.showStart
        width: win.dock.buttonSize
        height: win.dock.buttonSize

        Rectangle {
          anchors.fill: parent
          radius: 6
          color: startMouse.pressed ? Util.alpha(win.dock.text, 0.05)
            : startMouse.containsMouse ? Util.alpha(win.dock.text, 0.1)
            : "transparent"
          Behavior on color { ColorAnimation { duration: 120 } }
        }

        Grid {
          id: logo
          readonly property int cell: Math.round(win.dock.iconSize * 0.36)
          anchors.centerIn: parent
          columns: 2
          spacing: Math.max(1, Math.round(cell * 0.18))
          scale: startMouse.pressed ? 0.82 : 1
          Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

          Repeater {
            model: 4
            Rectangle {
              width: logo.cell
              height: logo.cell
              radius: 1
              color: win.dock.accent
            }
          }
        }

        MouseArea {
          id: startMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            win.dismissPopups()
            win.dock.runStart()
          }
        }
      }

      Repeater {
        model: win.dock.appModel

        TaskButton {
          dock: win.dock
          bar: win
        }
      }
    }

    // Clock
    Item {
      id: clock
      visible: win.dock.config.showClock && !win.dock.floating
      anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
      width: clockText.implicitWidth + 20
      height: win.dock.buttonSize

      SystemClock {
        id: time
        precision: SystemClock.Minutes
      }

      Rectangle {
        anchors.fill: parent
        radius: 6
        color: clockHover.hovered ? Util.alpha(win.dock.text, 0.1) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
      }

      HoverHandler { id: clockHover }

      Column {
        id: clockText
        anchors.centerIn: parent
        spacing: 1

        Text {
          anchors.right: parent.right
          textFormat: Text.PlainText
          text: Qt.formatTime(time.date, "HH:mm")
          color: win.dock.text
          font.family: win.dock.config.fontFamily
          font.pixelSize: 12
        }
        Text {
          anchors.right: parent.right
          textFormat: Text.PlainText
          text: Qt.formatDate(time.date, "dd.MM.yyyy")
          color: win.dock.text
          font.family: win.dock.config.fontFamily
          font.pixelSize: 12
        }
      }
    }
  }

  // ---- Hover preview -----------------------------------------------------

  PopupWindow {
    id: preview

    readonly property var info: win.previewButton ? win.previewButton.info : null
    readonly property real centerX: win.previewButton ? win.centerOf(win.previewButton) : 0

    visible: !!info && win.dock.config.showPreviews && !menu.visible && win.revealed
    color: "transparent"
    anchor.window: win
    anchor.rect.x: win.popupX(centerX, width)
    anchor.rect.y: -height - 8
    implicitWidth: previewCard.width
    implicitHeight: previewCard.height

    Rectangle {
      id: previewCard
      width: previewRow.width + 12
      height: previewRow.height + 12
      radius: 8
      color: win.dock.popupColor
      border.width: 1
      border.color: win.dock.stroke

      HoverHandler {
        id: previewHover
        onHoveredChanged: if (!hovered) previewClose.restart()
      }

      Row {
        id: previewRow
        x: 6
        y: 6
        spacing: 4

        // Not running: a plain name tooltip.
        Text {
          visible: !!preview.info && preview.info.windows.length === 0
          textFormat: Text.PlainText
          text: win.dock.appName(preview.info)
          color: win.dock.text
          font.family: win.dock.config.fontFamily
          font.pixelSize: 12
          leftPadding: 6
          rightPadding: 6
          topPadding: 2
          bottomPadding: 2
        }

        Repeater {
          model: preview.info ? preview.info.windows : []

          Rectangle {
            id: thumb
            required property var modelData

            width: 212
            height: 154
            radius: 6
            color: thumbMouse.containsMouse ? Util.alpha(win.dock.text, 0.1)
              : (thumb.modelData && thumb.modelData.activated) ? Util.alpha(win.dock.text, 0.05)
              : "transparent"

            MouseArea {
              id: thumbMouse
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                thumb.modelData.activate()
                win.dismissPopups()
              }
            }

            Image {
              id: thumbIcon
              x: 8
              y: 8
              width: 16
              height: 16
              sourceSize: Qt.size(32, 32)
              cache: false
              source: win.dock.iconFor(preview.info)
            }

            Text {
              anchors { left: thumbIcon.right; leftMargin: 8; right: closeButton.left; rightMargin: 4; verticalCenter: thumbIcon.verticalCenter }
              textFormat: Text.PlainText
              text: thumb.modelData ? thumb.modelData.title : ""
              elide: Text.ElideRight
              color: win.dock.text
              font.family: win.dock.config.fontFamily
              font.pixelSize: 12
            }

            Rectangle {
              id: closeButton
              anchors { right: parent.right; rightMargin: 4; top: parent.top; topMargin: 4 }
              width: 24
              height: 24
              radius: 4
              visible: thumbMouse.containsMouse || closeMouse.containsMouse
              color: closeMouse.containsMouse ? win.dock.urgent : "transparent"

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "✕"
                color: closeMouse.containsMouse ? "#ffffff" : win.dock.text
                font.pixelSize: 11
              }

              MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: thumb.modelData.close()
              }
            }

            Item {
              id: frame
              anchors { fill: parent; topMargin: 34; leftMargin: 8; rightMargin: 8; bottomMargin: 8 }

              // Shown until (or unless) the compositor delivers a frame.
              Image {
                anchors.centerIn: parent
                width: 40
                height: 40
                sourceSize: Qt.size(80, 80)
                cache: false
                source: win.dock.iconFor(preview.info)
                visible: !capture.hasContent
              }

              ScreencopyView {
                id: capture
                anchors.centerIn: parent
                captureSource: preview.visible ? thumb.modelData : null
                live: true
                constraintSize: Qt.size(frame.width, frame.height)
              }
            }
          }
        }
      }
    }
  }

  // ---- Right-click menu --------------------------------------------------

  PopupWindow {
    id: menu

    visible: false
    color: "transparent"
    anchor.window: win
    anchor.rect.x: win.popupX(win.menuCenterX, width)
    anchor.rect.y: -height - 8
    implicitWidth: 320
    implicitHeight: menuColumn.height + 8

    Rectangle {
      anchors.fill: parent
      radius: 8
      color: win.dock.popupColor
      border.width: 1
      border.color: win.dock.stroke

      Column {
        id: menuColumn
        x: 4
        y: 4
        width: parent.width - 8

        Repeater {
          model: win.menuItems

          Item {
            id: row
            required property var modelData
            readonly property bool separator: modelData.separator === true
            readonly property bool stepper: !!modelData.stepper

            width: menuColumn.width
            height: separator ? 9 : 34

            Rectangle {
              visible: row.separator
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width
              height: 1
              color: win.dock.stroke
            }

            Rectangle {
              visible: !row.separator
              anchors.fill: parent
              radius: 4
              color: rowMouse.containsMouse ? Util.alpha(win.dock.text, 0.1) : "transparent"
            }

            // [ − ] value [ + ]
            Row {
              id: stepperControls
              visible: row.stepper
              anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
              spacing: 2

              Repeater {
                model: row.stepper ? [-1, 0, 1] : []

                Rectangle {
                  id: stepButton
                  required property int modelData

                  width: modelData === 0 ? 34 : 26
                  height: 26
                  radius: 4
                  color: modelData !== 0 && stepMouse.containsMouse ? Util.alpha(win.dock.text, 0.12) : "transparent"
                  border.width: modelData === 0 ? 0 : 1
                  border.color: win.dock.stroke

                  Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: stepButton.modelData === 0 ? win.dock.config[row.modelData.stepper]
                      : stepButton.modelData < 0 ? "−" : "+"
                    color: win.dock.text
                    font.family: win.dock.config.fontFamily
                    font.pixelSize: 13
                  }

                  MouseArea {
                    id: stepMouse
                    anchors.fill: parent
                    enabled: stepButton.modelData !== 0
                    hoverEnabled: true
                    onClicked: win.stepSetting(row.modelData, stepButton.modelData)
                  }
                }
              }
            }

            Image {
              visible: !!row.modelData.icon
              anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
              width: 16
              height: 16
              sourceSize: Qt.size(32, 32)
              cache: false
              source: row.modelData.icon || ""
            }

            Text {
              visible: row.modelData.checked === true
              anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
              textFormat: Text.PlainText
              text: "✓"
              color: win.dock.text
              font.pixelSize: 13
            }

            Text {
              visible: !row.separator
              anchors {
                left: parent.left; leftMargin: 38
                right: row.stepper ? stepperControls.left : parent.right; rightMargin: 10
                verticalCenter: parent.verticalCenter
              }
              textFormat: Text.PlainText
              text: row.modelData.text || ""
              elide: Text.ElideRight
              color: win.dock.text
              font.family: win.dock.config.fontFamily
              font.pixelSize: 13
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              enabled: !row.separator && !row.stepper
              hoverEnabled: true
              onClicked: win.triggerMenu(row.modelData.id)
            }
          }
        }
      }
    }
  }

  HyprlandFocusGrab {
    windows: [menu]
    active: menu.visible
    onCleared: menu.visible = false
  }
}
