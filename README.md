# Emoji picker

A Quickshell / Qt Quick emoji picker for Hyprland. No AGS, Astal, GJS,
TypeScript, or Node.js installation is required.

The picker uses a regular desktop window (`FloatingWindow`) titled **Emoji Picker**.
Hyprland manages its placement, focus, and floating or tiled state through your
normal window rules. It does not use a layer-shell overlay or exclusive keyboard grab.

## Requirements

- `quickshell` (API target: **0.3.2**; see compatibility below)
- Hyprland and `hyprctl`
- `wl-copy` from `wl-clipboard`
- `ydotool`, with its daemon available at `/tmp/.ydotool_socket`, as in the
  original application
- An emoji-capable font

The migration does not install packages or configure the ydotool daemon.

### Quickshell compatibility

The application targets **Quickshell 0.3.2**, using its documented QML and IPC
APIs. This is the intended supported version, not a claim of completed runtime
testing. Other versions have not been verified; compatibility with older or
future releases is not guaranteed. Quickshell is pre-1.0 and may introduce API
breaks, as explained in its [distribution guide](https://quickshell.org/docs/v0.3.2/guide/distribution/).

The installer checks that `quickshell` is available, but does not enforce a
version or change your installed packages.

## Install for your user

With Quickshell installed, run from the project directory without sudo:

```sh
./install.sh
emoji-picker
```

The installer copies `shell.qml`, `PickerTheme.qml`, and `emojis.json` into
`${XDG_DATA_HOME:-$HOME/.local/share}/emoji-picker` and creates an executable launcher at
`~/.local/bin/emoji-picker`. It also installs `emoji-picker.desktop` under
`${XDG_DATA_HOME:-$HOME/.local/share}/applications`, so **Emoji Picker** appears
in desktop application launchers. The desktop entry uses the launcher's absolute
path, so it does not depend on `~/.local/bin` being in PATH.

The launcher runs Quickshell; it is not a standalone
compiled binary. The repository is no longer needed to run the installed copy.
Rerun the installer after changing the source to update that copy.

`XDG_DATA_HOME` defaults to `~/.local/share` when unset or empty. If you customize
it, use an absolute path and keep the same environment when installing, launching,
or uninstalling. For example, export it in your session environment before
running `./install.sh`. Changing it later does not move or remove an earlier
installation.

If `~/.local/bin` is not in your PATH, add this to your shell configuration:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Or run `~/.local/bin/emoji-picker` directly. The installer does not edit your
shell configuration, install dependencies, or create autostart entries.

Open or control the installed picker:

```sh
emoji-picker open
emoji-picker close
emoji-picker toggle
```

`open` and `toggle` start a background instance when none is running. Otherwise,
they control the existing window. `close` requires a running instance. Launching
**Emoji Picker** from an application launcher uses `open` as well. Running
`emoji-picker` or `emoji-picker start` directly starts it in the foreground.

For Hyprland, use these entries with the installed copy:

```ini
exec-once = ~/.local/bin/emoji-picker
bind = SUPER, E, exec, ~/.local/bin/emoji-picker toggle
```

### Make the window float

`FloatingWindow` creates a regular desktop window; Hyprland still decides whether
to tile or float it. For a floating picker, add this rule to your Hyprland Lua
configuration (for example, `~/.config/hypr/window.lua` if your main config loads it):

```lua
hl.window_rule({
    name = "emoji-picker-float",
    match = { title = "^Emoji Picker$" },
    float = true,
    center = true,
})
```

The rule applies when the window opens. Close and reopen the picker after the
configuration reloads. The installer does not modify your Hyprland configuration.
See the [Hyprland window rules documentation](https://wiki.hypr.land/configuring/core/rules/window-rules/).

## Uninstall

Run without sudo:

```sh
emoji-picker uninstall
```

If the command is not in PATH, use `~/.local/bin/emoji-picker uninstall`.
This removes the installed QML files, dataset, desktop entry, and executable launcher.
Any additional files in the application directory are kept. It does not remove
the repository, Quickshell, or other dependencies, and works even if Quickshell
has already been removed. Running instances are not stopped; exit them separately
and remove any Hyprland startup entries or keybindings you added.

## Run

From the project directory:

```sh
quickshell -p .
```

The picker opens on startup. Search by emoji name and filter by category using
the tabs above the grid. Click an emoji or press Enter in search to select the
first result. Down moves from search into the grid; use arrow keys and Enter to
select there. Up from the first row returns to search. Hovering or selecting an
emoji shows its name and subgroup in the footer. Escape or your window manager's close
shortcut (such as Super+Q) hides the picker without stopping the background
instance. Use `emoji-picker open` to show it again.

Selection copies the emoji, hides the picker, restores the application captured
when opening, and sends **Ctrl+Shift+V**, preserving the original paste shortcut.
Applications must support that shortcut. If there is no captured application,
the emoji is copied and an error is shown instead of sending keys elsewhere.
Focus or paste failures after hiding are reported in Quickshell's logs.

The existing `emojis.json` is loaded relative to `shell.qml`, so the project
can be moved without editing source paths.

## Theme

The picker reads `~/dotfiles/.config/theme/palette.conf` directly, matching the
single palette used by the dotfiles' theme renderer. It uses these existing roles:

- `base`, `surface`, `overlay`: window, search field, tabs, and hover backgrounds
- `text`, `subtle`, `muted`: text and scrollbar colors
- `hl_med`: borders and separators
- `accent`: selected tabs, keyboard selection, and search focus
- `love`: error messages
- `font`, `font_mono`, `font_size`: UI font, hint font, and point size

As in the dotfiles, `accent` can name a palette color (for example, `iris`) or
contain a six-digit hex color. Color values accept hex with or without `#`.
Font names can contain spaces. The file is read as data, never executed as shell
code. Wallpaper settings are ignored.

Palette edits update the running picker automatically. Opening the picker also
re-reads the palette, including after a previously missing file has been created.
There is no extra template or reload command to add to `theme.sh`.

If the palette is missing or unreadable, the picker uses a built-in Rosé Pine
palette with generic sans-serif and monospace fonts. Missing or invalid color
values and font sizes fall back individually; unrelated valid values still
apply. Font sizes must be positive numbers no larger than 72 points; the UI uses
a minimum base size of 8 points for readability. An unavailable font family
uses Qt's normal system font substitution. No dotfiles installation is required.

## Control a running picker

Use the same project path that was used to start the instance:

```sh
quickshell ipc -p . call picker open
quickshell ipc -p . call picker close
quickshell ipc -p . call picker toggle
```

For example, these Hyprland entries start the picker and toggle it with Super+E:

```ini
exec-once = quickshell -p /home/luay/me/projects/emoji-picker
bind = SUPER, E, exec, quickshell ipc -p /home/luay/me/projects/emoji-picker call picker toggle
```

Adjust the path if you move the project. The IPC commands require an already
running instance. Replace any previous AGS startup entries and keybindings.

The optional `package.json` only provides `start`, `open`, `close`, and `toggle`
aliases for npm/yarn users; it has no package dependencies and requires no install.
