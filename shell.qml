import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property var emojis: []
    property string loadError: ""
    property string actionError: ""
    property string targetAddress: ""
    property bool opening: false
    property bool busy: false
    readonly property var matches: {
        const query = search.text.toLowerCase();
        return emojis.filter(emoji => emoji.slug.includes(query)
            || emoji.unicodeName.toLowerCase().includes(query));
    }

    function openPicker() {
        if (busy || opening || captureWindow.running)
            return;
        if (picker.visible) {
            search.forceActiveFocus();
            return;
        }
        actionError = "";
        targetAddress = "";
        opening = true;
        captureWindow.running = true;
    }

    function closePicker() {
        opening = false;
        picker.visible = false;
    }

    function selectEmoji(emoji) {
        if (busy)
            return;
        actionError = "";
        busy = true;
        copyEmoji.command = ["wl-copy", "--", emoji.character];
        copyEmoji.running = true;
    }

    Component.onCompleted: openPicker()

    FileView {
        path: Qt.resolvedUrl("./emojis.json")
        onLoaded: {
            try {
                root.emojis = JSON.parse(text());
                root.loadError = "";
            } catch (error) {
                root.loadError = "Could not read emoji data: " + error;
            }
        }
        onLoadFailed: root.loadError = "Could not load emojis.json."
    }

    IpcHandler {
        target: "picker"
        function open(): void { root.openPicker(); }
        function close(): void { root.closePicker(); }
        function toggle(): void {
            if (picker.visible || root.opening)
                root.closePicker();
            else
                root.openPicker();
        }
    }

    Process {
        id: captureWindow
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector { id: activeWindowOutput }
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (!root.opening)
                return;
            root.opening = false;
            try {
                if (exitCode !== 0)
                    throw new Error("hyprctl failed");
                root.targetAddress = JSON.parse(activeWindowOutput.text).address || "";
            } catch (error) {
                root.actionError = "Could not capture the active window: " + error;
            }
            picker.visible = true;
            search.forceActiveFocus();
        }
    }

    Process {
        id: copyEmoji
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.busy = false;
                root.actionError = "Could not copy the emoji (wl-copy failed).";
                return;
            }
            if (!root.targetAddress) {
                root.busy = false;
                root.actionError = "Emoji copied, but there is no captured window to paste into.";
                return;
            }
            root.closePicker();
            // Hide the picker before restoring the target application's focus.
            Qt.callLater(() => {
                focusWindow.command = ["hyprctl", "dispatch", "focuswindow",
                    "address:" + root.targetAddress];
                focusWindow.running = true;
            });
        }
    }

    Process {
        id: focusWindow
        stdout: StdioCollector { id: focusOutput }
        stderr: StdioCollector { id: focusErrors }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.busy = false;
                const details = [focusOutput.text.trim(), focusErrors.text.trim()]
                    .filter(text => text.length > 0).join("\n");
                console.error("Emoji copied, but restoring window focus failed."
                    + "\nCommand: " + command.join(" ")
                    + "\nExit code: " + exitCode + "; exit status: " + exitStatus
                    + (details ? "\n" + details : "\nHyprland returned no error details."));
                return;
            }
            pasteEmoji.running = true;
        }
    }

    Process {
        id: pasteEmoji
        // Retain the original Ctrl+Shift+V shortcut and ydotool socket.
        environment: ({ YDOTOOL_SOCKET: "/tmp/.ydotool_socket" })
        command: ["ydotool", "key", "29:1", "42:1", "47:1", "29:0", "42:0", "47:0"]
        stderr: StdioCollector {}
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (exitCode !== 0)
                console.error("Emoji copied, but ydotool could not paste it.");
        }
    }

    FloatingWindow {
        id: picker
        visible: false
        title: "Emoji Picker"
        implicitHeight: Math.max(240, Math.floor(screen.height / 2))
        implicitWidth: Math.floor(implicitHeight * 4 / 3)
        minimumSize: Qt.size(240, 240)
        color: "#202024"

        onClosed: root.closePicker()

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => search.forceActiveFocus());
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Keys.onEscapePressed: root.closePicker()

            TextField {
                id: search
                Layout.fillWidth: true
                placeholderText: "Search emojis…"
                selectByMouse: true
                onTextChanged: {
                    grid.currentIndex = -1;
                    grid.positionViewAtBeginning();
                }
                Keys.onDownPressed: {
                    if (grid.count > 0) {
                        grid.currentIndex = 0;
                        grid.forceActiveFocus();
                    }
                }
                onAccepted: {
                    if (root.matches.length > 0)
                        root.selectEmoji(root.matches[0]);
                }
            }

            Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.loadError || root.actionError
                color: "#ffb4ab"
                wrapMode: Text.Wrap
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 40
                cellHeight: 40
                model: root.matches
                currentIndex: -1
                keyNavigationEnabled: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}

                Keys.onReturnPressed: {
                    if (currentIndex >= 0)
                        root.selectEmoji(root.matches[currentIndex]);
                }
                Keys.onEnterPressed: {
                    if (currentIndex >= 0)
                        root.selectEmoji(root.matches[currentIndex]);
                }

                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    radius: 4
                    color: mouse.containsMouse || GridView.isCurrentItem ? "#414149" : "transparent"
                    border.width: mouse.containsMouse || GridView.isCurrentItem ? 1 : 0
                    border.color: "#a0a0aa"

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.character
                        font.pixelSize: 24
                        color: "white"
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.busy
                        onClicked: root.selectEmoji(cell.modelData)
                    }

                    ToolTip.visible: mouse.containsMouse
                    ToolTip.delay: 500
                    ToolTip.text: modelData.unicodeName
                }

                Label {
                    anchors.centerIn: parent
                    visible: grid.count === 0 && !root.loadError
                    text: "No emojis found"
                    color: "#c0c0ca"
                }
            }
        }
    }
}
