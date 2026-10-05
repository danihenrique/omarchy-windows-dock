import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Entry point. Owns the config file, the palette and the app model; one
// Taskbar window per screen renders from it.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  readonly property string configPath: Quickshell.env("HOME") + "/.config/omarchy/win11-dock.json"

  // ---- Config ------------------------------------------------------------

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()
    // First run: materialize the defaults so the file is there to edit.
    onLoadFailed: function(error) {
      if (error === FileViewError.FileNotFound) writeAdapter()
    }

    JsonAdapter {
      id: config
      // Desktop entry ids (without ".desktop"), left to right.
      property list<string> pinned: []
      property bool floating: false
      property bool autoHide: false
      // "center" or "left"
      property string alignment: "center"
      // "theme" follows the Omarchy theme; "dark" / "light" use Windows 11 colors.
      property string colorScheme: "theme"
      property int barHeight: 48
      property int iconSize: 26
      property real opacity: 0.9
      property bool showStart: true
      property string startCommand: "omarchy-menu toggle apps"
      property bool showClock: true
      property bool showPreviews: true
      property string fontFamily: "sans-serif"
    }
  }

  readonly property alias config: config

  // ---- Metrics -----------------------------------------------------------

  readonly property int barHeight: Math.max(32, config.barHeight)
  readonly property int buttonSize: barHeight - 8
  readonly property int iconSize: Math.min(config.iconSize, buttonSize - 8)
  readonly property bool floating: config.floating
  readonly property bool autoHide: config.autoHide
  readonly property int floatMargin: floating ? 8 : 0

  // ---- Palette -----------------------------------------------------------

  readonly property bool themed: config.colorScheme !== "dark" && config.colorScheme !== "light"
  readonly property bool dark: themed ? Color.background.hslLightness < 0.5 : config.colorScheme === "dark"
  readonly property color surface: themed ? Color.background : (dark ? "#202020" : "#f3f3f3")
  readonly property color text: themed ? Color.foreground : (dark ? "#ffffff" : "#1b1b1b")
  readonly property color accent: themed ? Color.accent : (dark ? "#4cc2ff" : "#0067c0")
  readonly property color urgent: themed ? Color.urgent : "#c42b1c"
  readonly property color barColor: Util.alpha(surface, Util.clampAlpha(config.opacity))
  readonly property color popupColor: Qt.rgba(surface.r, surface.g, surface.b, 1)
  readonly property color stroke: Util.alpha(text, dark ? 0.1 : 0.14)

  // ---- App model ---------------------------------------------------------

  // appModel carries only the ordered keys so delegates survive window
  // open/close; the per-app data lives in appData and is looked up by key.
  ListModel { id: appModel }
  readonly property alias appModel: appModel
  property var appData: ({})

  function lookupEntry(id) {
    if (!id) return null
    return DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
  }

  function rebuild() {
    var data = {}
    var order = []
    var pinned = config.pinned

    for (var i = 0; i < pinned.length; i++) {
      var pinEntry = lookupEntry(pinned[i])
      var pinKey = (pinEntry ? pinEntry.id : pinned[i]).toLowerCase()
      if (data[pinKey]) continue
      data[pinKey] = { key: pinKey, pinId: pinned[i], appId: pinned[i], entry: pinEntry, pinned: true, windows: [] }
      order.push(pinKey)
    }

    var toplevels = ToplevelManager.toplevels.values
    for (var j = 0; j < toplevels.length; j++) {
      var toplevel = toplevels[j]
      var appId = toplevel.appId
      if (!appId) continue
      var entry = lookupEntry(appId)
      var key = (entry ? entry.id : appId).toLowerCase()
      if (!data[key]) {
        data[key] = { key: key, pinId: entry ? entry.id : appId, appId: appId, entry: entry, pinned: false, windows: [] }
        order.push(key)
      }
      data[key].windows.push(toplevel)
    }

    appData = data
    syncModel(order)
  }

  // Minimal diff so unchanged buttons keep their delegate (and animations).
  function syncModel(order) {
    for (var i = appModel.count - 1; i >= 0; i--) {
      if (order.indexOf(appModel.get(i).key) < 0) appModel.remove(i)
    }
    for (var j = 0; j < order.length; j++) {
      if (j < appModel.count && appModel.get(j).key === order[j]) continue
      var at = -1
      for (var k = j + 1; k < appModel.count; k++) {
        if (appModel.get(k).key === order[j]) { at = k; break }
      }
      if (at >= 0) appModel.move(at, j, 1)
      else appModel.insert(j, { key: order[j] })
    }
  }

  function scheduleRebuild() { Qt.callLater(rebuild) }

  Component.onCompleted: rebuild()

  Connections {
    target: config
    function onPinnedChanged() { root.scheduleRebuild() }
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.scheduleRebuild() }
  }

  Connections {
    target: DesktopEntries.applications
    function onValuesChanged() { root.scheduleRebuild() }
  }

  // A toplevel usually announces its appId a moment after it appears.
  Instantiator {
    model: ToplevelManager.toplevels
    delegate: Connections {
      required property var modelData
      target: modelData
      function onAppIdChanged() { root.scheduleRebuild() }
    }
  }

  // ---- Actions -----------------------------------------------------------

  function appName(info) {
    if (!info) return ""
    return info.entry ? info.entry.name : info.appId
  }

  function iconFor(info) {
    var name = info && info.entry ? info.entry.icon : (info ? info.appId : "")
    if (!name) return Quickshell.iconPath("application-x-executable")
    if (name.charAt(0) === "/") return Util.fileUrl(name)
    return Quickshell.iconPath(name, "application-x-executable")
  }

  function launch(info) {
    if (!info) return
    if (info.entry) Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", info.entry.id + ".desktop"])
    else Quickshell.execDetached(["uwsm-app", "--", info.appId])
  }

  // Left click: launch when not running, otherwise focus the app; clicking
  // the already focused app steps through its windows.
  function activate(info) {
    if (!info) return
    var windows = info.windows
    if (windows.length === 0) {
      launch(info)
      return
    }
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].activated) {
        if (windows.length > 1) windows[(i + 1) % windows.length].activate()
        return
      }
    }
    windows[0].activate()
  }

  function closeAll(info) {
    if (!info) return
    var windows = info.windows.slice()
    for (var i = 0; i < windows.length; i++) windows[i].close()
  }

  function pinIndex(info) {
    if (!info) return -1
    var pinned = config.pinned
    for (var i = 0; i < pinned.length; i++) {
      if (pinned[i] === info.pinId) return i
    }
    return -1
  }

  function pin(info) {
    if (!info || pinIndex(info) >= 0) return
    var pinned = Array.from(config.pinned)
    pinned.push(info.pinId)
    config.pinned = pinned
  }

  function unpin(info) {
    var at = pinIndex(info)
    if (at < 0) return
    var pinned = Array.from(config.pinned)
    pinned.splice(at, 1)
    config.pinned = pinned
  }

  function movePin(info, delta) {
    var at = pinIndex(info)
    var to = at + delta
    if (at < 0 || to < 0 || to >= config.pinned.length) return
    var pinned = Array.from(config.pinned)
    pinned.splice(to, 0, pinned.splice(at, 1)[0])
    config.pinned = pinned
  }

  // Drag reordering works on the model alone, so the dragged delegate stays
  // alive; the new order is written to the config once, on drop.
  function pinnedCount() {
    var count = 0
    for (var i = 0; i < appModel.count; i++) {
      var info = appData[appModel.get(i).key]
      if (info && info.pinned) count++
    }
    return count
  }

  function moveApp(from, to) {
    if (from !== to) appModel.move(from, to, 1)
  }

  function commitOrder() {
    var pinned = []
    for (var i = 0; i < appModel.count; i++) {
      var info = appData[appModel.get(i).key]
      if (info && info.pinned) pinned.push(info.pinId)
    }
    config.pinned = pinned
  }

  function runStart() {
    if (config.startCommand) Quickshell.execDetached(["sh", "-c", config.startCommand])
  }

  // ---- IPC ---------------------------------------------------------------

  // omarchy-shell win11-dock <function> [args], e.g. for Hyprland keybinds.
  IpcHandler {
    target: "win11-dock"

    function toggleAutoHide(): void { config.autoHide = !config.autoHide }
    function toggleFloating(): void { config.floating = !config.floating }
    function pin(id: string): void {
      if (config.pinned.indexOf(id) >= 0) return
      var pinned = Array.from(config.pinned)
      pinned.push(id)
      config.pinned = pinned
    }
    function unpin(id: string): void {
      config.pinned = Array.from(config.pinned).filter(function(pin) { return pin !== id })
    }
  }

  // ---- Windows -----------------------------------------------------------

  Variants {
    model: Quickshell.screens

    Taskbar {
      dock: root
    }
  }
}
