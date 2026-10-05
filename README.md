# Windows Dock for Omarchy

A Windows 11 style taskbar for the [Omarchy](https://omarchy.org/) shell
(Quickshell + Hyprland).

![preview](preview.png)

*Top: full-width taskbar following the Omarchy theme. Bottom: floating dock, and the Windows 11 dark color scheme.*

- Centered (or left-aligned) icons with a Start button
- Running apps get a small pill, the focused app a wide accent pill
- Hover a running app for live window thumbnails; click one to focus it, ✕ to close it
- Drag pinned icons left and right to reorder them
- Right-click an app: its desktop actions, new window, pin/unpin, reorder, close
- Right-click the bar: auto-hide, floating dock, alignment, clock, previews, transparent background, bar height, icon size and Start icon
- Full-width taskbar or a floating rounded dock
- Follows the Omarchy theme, or use the stock Windows 11 dark/light colors
- English and Russian menus (picked from the system locale)

## Install

```bash
omarchy plugin add https://github.com/maximxmoroz/omarchy-windows-dock.git --enable
```

Or by hand:

```bash
git clone https://github.com/maximxmoroz/omarchy-windows-dock.git ~/.config/omarchy/plugins/maximxmoroz.win11-dock
omarchy-shell shell rescanPlugins
omarchy plugin enable maximxmoroz.win11-dock
```

## Uninstall

```bash
omarchy plugin remove maximxmoroz.win11-dock
rm -f ~/.config/omarchy/win11-dock.json   # optional: drop your dock settings
```

## Requirements

Omarchy 4 (Quattro) on Hyprland. Nothing extra to install: the dock uses
`uwsm-app`, `gtk-launch` and `gsettings`, which Omarchy already ships. The
only file it writes is its own `~/.config/omarchy/win11-dock.json`.

## Usage

| Action | Result |
|---|---|
| Left click | Launch the app, or focus it. Clicking the focused app steps through its windows |
| Middle click | Open a new window |
| Drag sideways | Reorder a pinned app |
| Right click on an app | App menu |
| Right click on the bar | Dock settings |
| Hover | Window previews (name tooltip when the app isn't running) |

## Configuration

Settings live in `~/.config/omarchy/win11-dock.json` and apply on save. The
right-click menu on the bar edits the same file.

| Key | Default | |
|---|---|---|
| `pinned` | `[]` | Desktop entry ids without `.desktop`, left to right |
| `floating` | `false` | Rounded dock around the icons instead of a full-width bar |
| `autoHide` | `false` | Slide away; touch the bottom screen edge to bring it back |
| `alignment` | `"center"` | `"center"` or `"left"` |
| `colorScheme` | `"theme"` | `"theme"` (Omarchy theme), `"dark"` or `"light"` (Windows 11 colors) |
| `barHeight` | `48` | Bar height in px |
| `iconSize` | `26` | Icon size in px |
| `opacity` | `0.9` | Bar background opacity |
| `transparent` | `false` | No background and no edge line, only the icons |
| `showStart` | `true` | Show the Start button |
| `startCommand` | `"omarchy-menu toggle apps"` | Shell command the Start button runs |
| `startIcon` | `"windows"` | `"windows"`, `"omarchy"`, `"arch"`, `"linux"`, `"grid"`, or any icon name / absolute image path |
| `showClock` | `true` | Clock on the right (full-width bar only) |
| `showPreviews` | `true` | Hover previews and tooltips |
| `fontFamily` | `"sans-serif"` | Font for labels |

### Frosted background

For the mica look, turn on blur in Hyprland and add a layer rule to
`~/.config/hypr/looknfeel.lua`, then lower `opacity` to taste:

```lua
hl.layer_rule({ match = { namespace = "win11-dock" }, blur = true, ignore_alpha = 0.3 })
```

### Keybinds / scripting

```bash
omarchy-shell win11-dock toggleAutoHide
omarchy-shell win11-dock toggleFloating
omarchy-shell win11-dock pin org.gnome.Nautilus
omarchy-shell win11-dock unpin org.gnome.Nautilus
```

## Development

`Dock.qml` owns the config and the app model, `Taskbar.qml` is the bar window
with its popups, `TaskButton.qml` is one app button. The shell hot-reloads
the entry file, but edits to the other QML files only show up after
`omarchy restart shell`.

## License

MIT
