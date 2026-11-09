import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: theme

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property string palettePath: Quickshell.env("EMOJI_PICKER_PALETTE") || configHome + "/theme/palette.conf"
    readonly property var defaults: ({
        base: "191724", surface: "1f1d2e", overlay: "26233a",
        muted: "6e6a86", subtle: "908caa", text: "e0def4",
        love: "eb6f92", gold: "f6c177", rose: "ebbcba",
        pine: "31748f", foam: "9ccfd8", iris: "c4a7e7",
        hl_low: "21202e", hl_med: "403d52", hl_high: "524f67",
        accent: "c4a7e7", font: "Sans Serif", font_mono: "Monospace", font_size: 11
    })
    property var values: defaults

    readonly property color base: "#" + values.base
    readonly property color surface: "#" + values.surface
    readonly property color overlay: "#" + values.overlay
    readonly property color muted: "#" + values.muted
    readonly property color subtle: "#" + values.subtle
    readonly property color text: "#" + values.text
    readonly property color love: "#" + values.love
    readonly property color accent: "#" + values.accent
    readonly property color highlight: "#" + values.hl_med
    readonly property string fontFamily: values.font
    readonly property string monoFamily: values.font_mono
    readonly property real fontSize: Math.max(8, values.font_size)

    function applyPalette(content) {
        const entries = {};
        for (const line of content.split(/\r?\n/)) {
            const trimmed = line.trim();
            if (!trimmed || trimmed.startsWith("#"))
                continue;
            const separator = trimmed.indexOf("=");
            if (separator < 1)
                continue;
            entries[trimmed.slice(0, separator).trim()] = trimmed.slice(separator + 1).trim();
        }

        const next = Object.assign({}, defaults);
        for (const key of Object.keys(defaults)) {
            if (key === "accent" || key.startsWith("font"))
                continue;
            const value = (entries[key] || "").replace(/^#/, "");
            if (/^[0-9a-f]{6}$/i.test(value))
                next[key] = value;
        }
        const accent = entries.accent || "iris";
        if (Object.prototype.hasOwnProperty.call(next, accent) && /^[0-9a-f]{6}$/i.test(next[accent]))
            next.accent = next[accent];
        else if (/^#?[0-9a-f]{6}$/i.test(accent))
            next.accent = accent.replace(/^#/, "");
        for (const key of ["font", "font_mono"]) {
            if (entries[key])
                next[key] = entries[key];
        }
        const size = Number(entries.font_size);
        if (Number.isFinite(size) && size > 0 && size <= 72)
            next.font_size = size;
        values = next;
    }

    function reload() {
        paletteFile.reload();
    }

    FileView {
        id: paletteFile
        path: theme.palettePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: theme.applyPalette(text())
        onLoadFailed: theme.values = theme.defaults
    }
}
