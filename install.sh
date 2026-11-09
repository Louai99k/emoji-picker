#!/bin/sh
set -eu

if [ "$(id -u)" -eq 0 ]; then
    printf '%s\n' 'Run this script as your normal user, without sudo.' >&2
    exit 1
fi

: "${HOME:?HOME must be set}"
case "$HOME" in
    /*) ;;
    *) printf '%s\n' 'HOME must be an absolute path.' >&2; exit 1 ;;
esac

if ! command -v quickshell >/dev/null 2>&1; then
    printf '%s\n' 'Quickshell is required. Install it using your package manager, then rerun this script.' >&2
    exit 1
fi

source_dir=$(CDPATH='' cd -P "$(dirname -- "$0")" && pwd)
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
case "$data_home" in
    /*) ;;
    *) printf '%s\n' 'XDG_DATA_HOME must be an absolute path.' >&2; exit 1 ;;
esac
app_dir="$data_home/emoji-picker"
bin_dir="$HOME/.local/bin"
desktop_dir="$data_home/applications"

for filename in shell.qml emojis.json; do
    if [ ! -f "$source_dir/$filename" ]; then
        printf 'Missing application file: %s\n' "$source_dir/$filename" >&2
        exit 1
    fi
done

mkdir -p "$app_dir" "$bin_dir" "$desktop_dir"
if [ "$source_dir" != "$app_dir" ]; then
    install -m 644 "$source_dir/shell.qml" "$app_dir/shell.qml"
    install -m 644 "$source_dir/emojis.json" "$app_dir/emojis.json"
fi

cat > "$bin_dir/emoji-picker" <<'LAUNCHER'
#!/bin/sh
set -eu

: "${HOME:?HOME must be set}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
case "$data_home" in
    /*) ;;
    *) printf '%s\n' 'XDG_DATA_HOME must be an absolute path.' >&2; exit 1 ;;
esac
app_dir="$data_home/emoji-picker"

if [ "$#" -gt 1 ]; then
    printf '%s\n' 'Expected at most one command. See emoji-picker --help.' >&2
    exit 1
fi

case "${1:-start}" in
    -h|--help)
        printf '%s\n' \
            'Usage: emoji-picker [start|open|close|toggle|uninstall]' \
            'With no arguments, starts the picker.' \
            'open, close, and toggle control an already running instance.' \
            'uninstall removes the installed files and launcher for this user.'
        exit 0
        ;;
    uninstall)
        # Remove only files owned by this installer, retaining any extra files.
        rm -f -- "$app_dir/shell.qml" "$app_dir/emojis.json" \
            "$data_home/applications/emoji-picker.desktop"
        if [ -d "$app_dir" ]; then
            rmdir -- "$app_dir" 2>/dev/null || :
        fi
        rm -f -- "$HOME/.local/bin/emoji-picker"
        printf '%s\n' 'Uninstalled emoji-picker. Quickshell and other dependencies were kept.'
        exit 0
        ;;
    start|open|close|toggle) ;;
    *) printf 'Unknown command: %s\n' "$1" >&2; exit 1 ;;
esac

if ! command -v quickshell >/dev/null 2>&1; then
    printf '%s\n' 'Quickshell is required but was not found in PATH.' >&2
    exit 1
fi

if [ ! -f "$app_dir/shell.qml" ] || [ ! -f "$app_dir/emojis.json" ]; then
    printf '%s\n' 'Emoji picker files are missing. Rerun install.sh from the project.' >&2
    exit 1
fi

case "${1:-start}" in
    start) exec quickshell -p "$app_dir" ;;
    open|close|toggle) exec quickshell ipc -p "$app_dir" call picker "$1" ;;
esac
LAUNCHER

chmod 755 "$bin_dir/emoji-picker"

# Desktop entries apply string escaping before command-line quoting.
desktop_exec=$(printf '%s' "$bin_dir/emoji-picker" | sed \
    -e 's/\\/\\\\\\\\/g' \
    -e 's/"/\\\\"/g' \
    -e 's/`/\\\\`/g' \
    -e 's/\$/\\\\$/g' \
    -e 's/%/%%/g')
cat > "$desktop_dir/emoji-picker.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Emoji Picker
Comment=Search and copy emojis
Exec="$desktop_exec"
Icon=accessories-character-map
Terminal=false
Categories=Utility;
Keywords=emoji;unicode;clipboard;
DESKTOP
chmod 644 "$desktop_dir/emoji-picker.desktop"

printf 'Installed application: %s\nCommand: %s\nDesktop entry: %s\n' \
    "$app_dir" "$bin_dir/emoji-picker" "$desktop_dir/emoji-picker.desktop"
case ":${PATH:-}:" in
    *":$bin_dir:"*) printf '%s\n' 'Run: emoji-picker' ;;
    *)
        printf '%s\n' \
            'Add this line to your shell configuration to use the command by name:' \
            'export PATH="$HOME/.local/bin:$PATH"'
        printf 'Or run directly: "%s/emoji-picker"\n' "$bin_dir"
        ;;
esac
