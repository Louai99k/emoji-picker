import QtQuick
import QtQuick.Controls.Basic
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
    property string selectedGroup: ""
    property var hoveredEmoji: null
    readonly property var categories: [
        { group: "", label: "All" },
        { group: "smileys-emotion", label: "Faces" },
        { group: "people-body", label: "People" },
        { group: "animals-nature", label: "Nature" },
        { group: "food-drink", label: "Food" },
        { group: "travel-places", label: "Travel" },
        { group: "activities", label: "Activities" },
        { group: "objects", label: "Objects" },
        { group: "symbols", label: "Symbols" },
        { group: "flags", label: "Flags" }
    ]
    readonly property var previewEmoji: hoveredEmoji || (grid ? matches[grid.currentIndex] : null) || null
    readonly property var matches: {
        const query = search.text.trim().toLowerCase();
        return emojis.filter(emoji => (!selectedGroup || emoji.group === selectedGroup)
            && (emoji.slug.includes(query) || emoji.unicodeName.toLowerCase().includes(query)));
    }

    function emojiName(emoji) {
        return emoji ? emoji.unicodeName.replace(/^E[\d.]+\s+/, "") : "Choose an emoji";
    }

    onMatchesChanged: {
        hoveredEmoji = null;
        if (grid) {
            grid.currentIndex = -1;
            grid.positionViewAtBeginning();
        }
    }

    PickerTheme { id: theme }

    function openPicker() {
        theme.reload();
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
        implicitHeight: Math.min(560, Math.floor(screen.height * 0.7))
        implicitWidth: 640
        minimumSize: Qt.size(360, 360)
        color: theme.base

        onClosed: root.closePicker()

        onVisibleChanged: {
            if (visible)
                Qt.callLater(() => search.forceActiveFocus());
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: theme.highlight
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Keys.onEscapePressed: root.closePicker()

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 8
                    color: Qt.alpha(theme.accent, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: "☺"
                        font.pixelSize: 25
                        color: theme.accent
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Emoji picker"
                    color: theme.text
                    font.family: theme.fontFamily
                    font.pointSize: theme.fontSize + 3
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.matches.length.toLocaleString() + " emojis"
                    color: theme.subtle
                    font.family: theme.monoFamily
                    font.pointSize: theme.fontSize - 1
                }

                Button {
                    id: closeButton
                    implicitWidth: 32
                    implicitHeight: 32
                    text: "×"
                    Accessible.name: "Close emoji picker"
                    onClicked: root.closePicker()
                    background: Rectangle {
                        radius: 6
                        color: closeButton.hovered || closeButton.visualFocus ? theme.overlay : "transparent"
                        border.width: closeButton.visualFocus ? 1 : 0
                        border.color: theme.accent
                    }
                    contentItem: Text {
                        text: closeButton.text
                        color: closeButton.hovered ? theme.text : theme.subtle
                        font.pixelSize: 23
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            TextField {
                id: search
                Layout.fillWidth: true
                implicitHeight: 46
                leftPadding: 14
                rightPadding: 14
                placeholderText: "Search by name…"
                color: theme.text
                placeholderTextColor: theme.subtle
                selectionColor: theme.accent
                selectedTextColor: theme.base
                font.family: theme.fontFamily
                font.pointSize: theme.fontSize
                selectByMouse: true
                background: Rectangle {
                    radius: 8
                    color: theme.surface
                    border.width: 1
                    border.color: search.activeFocus ? theme.accent : theme.highlight
                }
                Keys.onDownPressed: {
                    if (grid.count > 0) {
                        grid.currentIndex = 0;
                        grid.forceActiveFocus();
                    }
                }
                onAccepted: if (root.matches.length > 0) root.selectEmoji(root.matches[0])
            }

            Flickable {
                Layout.fillWidth: true
                implicitHeight: 32
                contentWidth: categoryRow.width
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Row {
                    id: categoryRow
                    spacing: 6

                    Repeater {
                        model: root.categories
                        delegate: Button {
                            id: categoryButton
                            required property var modelData
                            readonly property bool selected: root.selectedGroup === modelData.group
                            text: modelData.label
                            implicitHeight: 32
                            leftPadding: 12
                            rightPadding: 12
                            onClicked: root.selectedGroup = modelData.group
                            Accessible.name: modelData.label + " emojis"
                            background: Rectangle {
                                radius: 6
                                color: categoryButton.selected ? theme.accent
                                    : categoryButton.hovered ? theme.overlay : theme.surface
                                border.width: categoryButton.visualFocus ? 1 : 0
                                border.color: theme.accent
                            }
                            contentItem: Text {
                                text: categoryButton.text
                                color: categoryButton.selected ? theme.base : theme.subtle
                                font.family: theme.fontFamily
                                font.pointSize: theme.fontSize - 1
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: theme.highlight
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: errorText.implicitHeight + 20
                visible: errorText.text.length > 0
                radius: 6
                color: Qt.alpha(theme.love, 0.1)
                Text {
                    id: errorText
                    anchors.fill: parent
                    anchors.margins: 10
                    text: root.loadError || root.actionError
                    color: theme.love
                    font.family: theme.fontFamily
                    font.pointSize: theme.fontSize - 1
                    wrapMode: Text.Wrap
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                // Whole columns fill the available width, including after a resize.
                cellWidth: width / Math.max(1, Math.floor((width - 12) / 56))
                cellHeight: 60
                model: root.matches
                currentIndex: -1
                keyNavigationEnabled: true
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                ScrollBar.vertical: ScrollBar {
                    id: scrollBar
                    width: 5
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 5
                        implicitHeight: 32
                        radius: 2
                        color: scrollBar.pressed ? theme.accent : theme.muted
                        opacity: scrollBar.size < 1 ? 0.7 : 0
                    }
                    background: Item {}
                }

                Keys.onReturnPressed: if (currentIndex >= 0) root.selectEmoji(root.matches[currentIndex])
                Keys.onEnterPressed: if (currentIndex >= 0) root.selectEmoji(root.matches[currentIndex])
                Keys.onUpPressed: event => {
                    if (currentIndex < Math.floor(width / cellWidth)) {
                        search.forceActiveFocus();
                        currentIndex = -1;
                    } else {
                        event.accepted = false;
                    }
                }

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool selected: GridView.isCurrentItem
                    Accessible.role: Accessible.Button
                    Accessible.name: root.emojiName(modelData)
                    Accessible.onPressAction: root.selectEmoji(modelData)

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 8
                        color: cell.selected ? Qt.alpha(theme.accent, 0.16)
                            : mouse.containsMouse ? theme.overlay : "transparent"
                        border.width: cell.selected ? 1 : 0
                        border.color: theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.character
                            font.pixelSize: 29
                            color: theme.text
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.busy
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoveredEmoji = cell.modelData
                        onExited: if (root.hoveredEmoji === cell.modelData) root.hoveredEmoji = null
                        onClicked: root.selectEmoji(cell.modelData)
                    }
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 8
                    visible: grid.count === 0 && !root.loadError
                    Text {
                        width: parent.width
                        text: "No matching emojis"
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pointSize: theme.fontSize + 1
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        width: parent.width
                        text: "Try another name or category."
                        color: theme.subtle
                        font.family: theme.fontFamily
                        font.pointSize: theme.fontSize - 1
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: theme.highlight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.preferredWidth: 34
                    text: root.previewEmoji ? root.previewEmoji.character : "☺"
                    color: theme.accent
                    font.pixelSize: 27
                    horizontalAlignment: Text.AlignHCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        Layout.fillWidth: true
                        text: root.emojiName(root.previewEmoji)
                        color: theme.text
                        font.family: theme.fontFamily
                        font.pointSize: theme.fontSize - 1
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.busy ? "Copying…" : root.previewEmoji
                            ? root.previewEmoji.subGroup.replace(/-/g, " ") : "Hover or use the arrow keys"
                        color: theme.subtle
                        font.family: theme.fontFamily
                        font.pointSize: theme.fontSize - 2
                        elide: Text.ElideRight
                    }
                }

                Text {
                    visible: picker.width >= 480
                    text: "Enter  select   ·   Esc  close"
                    color: theme.subtle
                    font.family: theme.monoFamily
                    font.pointSize: theme.fontSize - 2
                }
            }
        }
    }
}
