import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    visible: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "mango-layout-switcher"
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // Settings
    FileView {
        id: settingsFile

        path: Quickshell.shellDir + "/mango-layout-switcher.json"
        watchChanges: true

        JsonAdapter {
            id: settings

            property var monitorOrder: []
        }
    }

    function saveSettings() {
        settingsFile.writeAdapter();
    }

    // Icons
    FontLoader {
        id: iconFont

        source: Qt.resolvedUrl("Assets/Icons/tabler-icons.ttf")
    }

    readonly property var tablerIcons: ({
        "layout-grid": "",
        "layout-sidebar": "",
        "rectangle": "",
        "carousel-horizontal": "",
        "carousel-vertical": "",
        "layout-rows": "",
        "grid-dots": "",
        "versions": "",
        "layout-sidebar-right": "",
        "layout-distribute-vertical": "",
        "layout-dashboard": "",
        "chart-funnel": "ﻵ",
        "grip-vertical": "",
        "check": ""
    })
    readonly property var iconMap: ({
        "T": "layout-sidebar",
        "M": "rectangle",
        "S": "carousel-horizontal",
        "G": "layout-grid",
        "K": "versions",
        "RT": "layout-sidebar-right",
        "CT": "layout-distribute-vertical",
        "TG": "layout-dashboard",
        "VT": "layout-rows",
        "VS": "carousel-vertical",
        "VG": "grid-dots",
        "VK": "chart-funnel"
    })

    function icon(name) {
        return tablerIcons[name] || "";
    }

    // Layout state
    QtObject {
        id: layoutState

        property var monitorLayouts: ({})
        property var availableLayouts: []
        property var availableMonitors: []
        readonly property var layoutNames: ({
            "S": "Scroller",
            "T": "Tile",
            "G": "Grid",
            "M": "Monocle",
            "K": "Deck",
            "CT": "Center Tile",
            "RT": "Right Tile",
            "VS": "Vertical Scroller",
            "VT": "Vertical Tile",
            "VG": "Vertical Grid",
            "VK": "Vertical Deck",
            "TG": "Tgmix"
        })

        function getLayoutName(code) {
            return layoutNames[code] || code.replace(/_/g, " ").replace(/\b\w/g, function (c) {
                return c.toUpperCase();
            });
        }

        function updateLayout(monitor, layout) {
            var clean = layout ? layout.trim() : "";
            if (clean && monitor && monitorLayouts[monitor] !== clean) {
                monitorLayouts[monitor] = clean;
                monitorLayoutsChanged();
            }
        }

        function setLayout(monitorName, layoutCode) {
            if (!monitorName || !layoutCode)
                return;
            Quickshell.execDetached(["mmsg", "-o", monitorName, "-s", "-l", layoutCode]);
            updateLayout(monitorName, layoutCode);
        }

        function setLayoutGlobally(layoutCode) {
            availableMonitors.forEach(function (m) {
                setLayout(m, layoutCode);
            });
        }
    }

    // Processes
    Process {
        id: eventWatcher

        command: ["mmsg", "-w"]
        running: true

        stdout: SplitParser {
            onRead: function (line) {
                var m = line.match(/^(\S+)\s+layout\s+(\S+)$/);
                if (m)
                    layoutState.updateLayout(m[1], m[2]);
            }
        }
    }

    Process {
        id: layoutsQuery

        property var tempArray: []

        command: ["mmsg", "-L"]
        running: true

        stdout: SplitParser {
            onRead: function (line) {
                var code = line.trim();
                if (code && !layoutsQuery.tempArray.some(function (l) {
                    return l.code === code;
                }))
                    layoutsQuery.tempArray.push({
                        "code": code,
                        "name": layoutState.getLayoutName(code)
                    });
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0)
                layoutState.availableLayouts = tempArray;
        }
    }

    Process {
        id: monitorsQuery

        property var tempArray: []

        command: ["mmsg", "-O"]
        running: true

        stdout: SplitParser {
            onRead: function (line) {
                var m = line.trim();
                if (m && !monitorsQuery.tempArray.includes(m))
                    monitorsQuery.tempArray.push(m);
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0)
                layoutState.availableMonitors = tempArray;
        }
    }

    // App state
    property var orderedMonitors: {
        var all = layoutState.availableMonitors;
        var order = settings.monitorOrder;
        if (!order || !order.length)
            return all;
        return order.filter(function (m) {
            return all.includes(m);
        }).concat(all.filter(function (m) {
            return !order.includes(m);
        }));
    }
    property bool applyToAll: false
    property var selectedMonitors: []
    readonly property string panelMonitor: orderedMonitors.length > 0 ? orderedMonitors[0] : ""
    readonly property var layouts: layoutState.availableLayouts
    readonly property string activeLayout: {
        var mon = selectedMonitors.length > 0 ? selectedMonitors[0] : panelMonitor;
        return layoutState.monitorLayouts[mon] || "";
    }
    readonly property real panelHeight: panelLayout.implicitHeight + Config.panelMargin * 2

    // Keyboard navigation state
    property int keyboardFocusedIndex: -1
    property string lastFocusMethod: "hover"
    readonly property int gridColumns: 3

    function navigateKeyboard(direction) {
        var count = layoutState.availableLayouts.length;
        if (count === 0) return;

        var idx = keyboardFocusedIndex;
        if (idx < 0 || idx >= count) {
            var activeIdx = root.layouts.findIndex(l => l.code === root.activeLayout);
            idx = activeIdx >= 0 ? activeIdx : 0;
        }

        var currentRow = Math.floor(idx / gridColumns);
        var currentCol = idx % gridColumns;
        var totalRows = Math.ceil(count / gridColumns);

        switch (direction) {
            case "left":
                if (currentCol > 0) {
                    idx--;
                } else {
                    idx = currentRow * gridColumns + (gridColumns - 1);
                    if (idx >= count) idx = count - 1;
                }
                break;
            case "right":
                if (currentCol < gridColumns - 1 && idx + 1 < count) {
                    idx++;
                } else {
                    idx = currentRow * gridColumns;
                }
                break;
            case "up":
                if (currentRow > 0) {
                    idx -= gridColumns;
                } else {
                    idx = (totalRows - 1) * gridColumns + currentCol;
                    if (idx >= count) idx = count - 1;
                }
                break;
            case "down":
                if (idx + gridColumns < count) {
                    idx += gridColumns;
                } else {
                    idx = currentCol;
                }
                break;
        }

        keyboardFocusedIndex = idx;
        lastFocusMethod = "keyboard";
    }

    function applyFocusedLayout() {
        if (keyboardFocusedIndex >= 0 && keyboardFocusedIndex < layoutState.availableLayouts.length) {
            applyLayout(layoutState.availableLayouts[keyboardFocusedIndex].code);
        }
    }

    function applyMonitorReorder(from, to) {
        if (from === to)
            return;
        var arr = orderedMonitors.slice();
        arr.splice(to, 0, arr.splice(from, 1)[0]);
        settings.monitorOrder = arr;
        saveSettings();
    }

    function toggleMonitor(name) {
        selectedMonitors = selectedMonitors.includes(name) ? selectedMonitors.filter(function (m) {
            return m !== name;
        }) : selectedMonitors.concat([name]);
    }

    function applyLayout(code) {
        if (applyToAll)
            layoutState.setLayoutGlobally(code);
        else if (selectedMonitors.length > 0)
            selectedMonitors.forEach(function (m) {
                layoutState.setLayout(m, code);
            });
        else
            layoutState.setLayout(panelMonitor, code);
    }

    // UI
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }

    Rectangle {
        id: panelContent
        anchors.centerIn: parent
        width: Config.panelWidth
        height: root.panelHeight
        color: Config.cSurface
        radius: Config.panelRadius
        border.width: 1
        border.color: Config.cOutline
        focus: true

        Component.onCompleted: {
            forceActiveFocus();
            var activeIdx = root.layouts.findIndex(l => l.code === root.activeLayout);
            if (activeIdx >= 0) {
                keyboardFocusedIndex = activeIdx;
                lastFocusMethod = "keyboard";
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: function (mouse) {
                mouse.accepted = true;
            }
        }

        Keys.onPressed: event => {
            switch (event.key) {
                case Qt.Key_H:
                case Qt.Key_Left:
                    root.navigateKeyboard("left");
                    event.accepted = true;
                    break;
                case Qt.Key_L:
                case Qt.Key_Right:
                    root.navigateKeyboard("right");
                    event.accepted = true;
                    break;
                case Qt.Key_J:
                case Qt.Key_Down:
                    root.navigateKeyboard("down");
                    event.accepted = true;
                    break;
                case Qt.Key_K:
                case Qt.Key_Up:
                    root.navigateKeyboard("up");
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Space:
                    if (root.keyboardFocusedIndex >= 0) {
                        root.applyFocusedLayout();
                    }
                    event.accepted = true;
                    break;
                case Qt.Key_Escape:
                    Qt.quit();
                    event.accepted = true;
                    break;
            }
        }

        ColumnLayout {
            id: panelLayout

            anchors.fill: parent
            anchors.margins: Config.panelMargin
            spacing: Config.spacingL

            // Header
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight + Config.headerPadding
                color: Config.cSurfaceVariant
                radius: Config.headerRadius

                RowLayout {
                    id: headerRow

                    anchors.centerIn: parent
                    width: parent.width - Config.headerPadding
                    spacing: Config.spacingM

                    Text {
                        text: root.icon("layout-grid")
                        font.family: iconFont.name
                        font.pixelSize: Config.fsBase
                        color: Config.cPrimary
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        text: "Switch Layout"
                        font.pixelSize: Config.fsBase
                        font.weight: Font.Bold
                        color: Config.cFgSurface
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                    }
                }
            }

            // Apply-to-all toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: Config.spacingM

                Text {
                    text: "Apply to all monitors"
                    font.pixelSize: Config.fsBase
                    font.weight: Font.Medium
                    color: Config.cFgVariant
                    verticalAlignment: Text.AlignVCenter
                    Layout.fillWidth: true
                }

                Rectangle {
                    id: toggler

                    implicitWidth: Config.toggleWidth
                    implicitHeight: Config.toggleHeight
                    radius: Config.toggleHeight / 2
                    color: root.applyToAll ? Config.cPrimary : Config.cSurface
                    border.width: 1
                    border.color: Config.cOutline

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Rectangle {
                        width: Config.toggleKnob
                        height: Config.toggleKnob
                        radius: Config.toggleKnob / 2
                        color: root.applyToAll ? Config.cFgPrimary : Config.cPrimary
                        border.width: 2
                        border.color: Config.cSurface
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.applyToAll ? parent.width - width - 2 : 2

                        Behavior on x {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.applyToAll = !root.applyToAll;
                            if (!root.applyToAll && root.selectedMonitors.length === 0)
                                root.selectedMonitors = [root.panelMonitor];
                        }
                    }
                }
            }

            // Monitor selector
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Config.spacingS
                opacity: root.applyToAll ? 0.6 : 1.0
                enabled: !root.applyToAll

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Config.spacingS

                    Text {
                        text: "Select monitors"
                        font.pixelSize: Config.fsBase
                        font.weight: Font.Medium
                        color: Config.cFgVariant
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.icon("grip-vertical")
                        font.family: iconFont.name
                        font.pixelSize: Config.fsBase
                        color: Config.cFgVariant
                        opacity: 0.5
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Item {
                    id: dragArea

                    property int draggedIndex: -1
                    property int dropTargetIndex: -1
                    property bool dragging: false
                    property bool pendingDrag: false
                    property point startPos: Qt.point(0, 0)
                    readonly property real threshold: 8

                    Layout.fillWidth: true
                    implicitHeight: chipFlow.implicitHeight

                    function chipRect(i) {
                        var c = chipRepeater.itemAt(i);
                        if (!c)
                            return Qt.rect(0, 0, 0, 0);
                        var p = c.mapToItem(chipFlow, 0, 0);
                        return Qt.rect(p.x, p.y, c.width, c.height);
                    }

                    function computeDropIndex(mx, my) {
                        var count = root.orderedMonitors.length;
                        var best = draggedIndex;
                        var bestDist = Infinity;
                        for (var i = 0; i < count; i++) {
                            if (i === draggedIndex)
                                continue;
                            var r = chipRect(i);
                            if (!r.width)
                                continue;
                            var dist = Math.hypot(mx - (r.x + r.width / 2), my - (r.y + r.height / 2));
                            if (dist < bestDist) {
                                bestDist = dist;
                                best = mx < r.x + r.width / 2 ? i : i + 1;
                            }
                        }
                        if (best > draggedIndex)
                            best--;
                        return Math.max(0, Math.min(count - 1, best));
                    }

                    function reset() {
                        draggedIndex = -1;
                        dropTargetIndex = -1;
                        dragging = false;
                        pendingDrag = false;
                        dropGhost.visible = false;
                    }

                    Rectangle {
                        id: dropIndicator

                        width: 2
                        height: Config.chipHeight
                        radius: 1
                        color: Config.cPrimary
                        visible: dragArea.dragging && dragArea.dropTargetIndex !== -1
                        z: 10

                        SequentialAnimation on opacity {
                            running: dropIndicator.visible
                            loops: Animation.Infinite

                            NumberAnimation {
                                to: 1.0
                                duration: 350
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                to: 0.5
                                duration: 350
                                easing.type: Easing.InOutQuad
                            }
                        }

                        Behavior on x {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on y {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Rectangle {
                        id: dropGhost

                        width: ghostLabel.implicitWidth + Config.chipPadding
                        height: Config.chipHeight
                        radius: Config.chipRadius
                        color: Config.cPrimary
                        opacity: 0.85
                        visible: false
                        z: 20

                        Text {
                            id: ghostLabel

                            anchors.centerIn: parent
                            font.pixelSize: Config.fsSmall
                            font.weight: Font.Medium
                            color: Config.cFgPrimary
                        }
                    }

                    Flow {
                        id: chipFlow

                        width: parent.width
                        spacing: Config.spacingS

                        Repeater {
                            id: chipRepeater

                            model: root.orderedMonitors

                            delegate: Rectangle {
                                id: chip

                                required property int index
                                required property string modelData

                                readonly property bool selected: root.applyToAll || root.selectedMonitors.includes(modelData)
                                readonly property bool beingDragged: dragArea.draggedIndex === index && dragArea.dragging

                                width: beingDragged ? chipInner.implicitWidth + Config.chipPadding - 4 : chipInner.implicitWidth + Config.chipPadding
                                height: Config.chipHeight
                                radius: Config.chipRadius
                                color: selected ? Config.cPrimary : Config.cSurfaceVariant
                                border.width: 1
                                border.color: selected ? Config.cPrimary : Config.cOutline
                                opacity: beingDragged ? 0.35 : 1.0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                RowLayout {
                                    id: chipInner

                                    anchors.centerIn: parent
                                    spacing: Config.spacingS

                                    Text {
                                        text: root.icon("grip-vertical")
                                        font.family: iconFont.name
                                        font.pixelSize: Config.fsChip
                                        color: chip.selected ? Qt.alpha(Config.cFgPrimary, 0.6) : Config.cFgVariant
                                        opacity: 0.7
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        visible: chip.selected
                                        text: root.icon("check")
                                        font.family: iconFont.name
                                        font.pixelSize: Config.fsChip
                                        color: Config.cFgPrimary
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        text: modelData
                                        font.pixelSize: Config.fsChip
                                        font.weight: Font.Medium
                                        color: chip.selected ? Config.cFgPrimary : Config.cFgSurface
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: chipFlow
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true
                        hoverEnabled: dragArea.pendingDrag || dragArea.dragging
                        cursorShape: dragArea.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                        onPressed: function (mouse) {
                            dragArea.startPos = Qt.point(mouse.x, mouse.y);
                            dragArea.dragging = false;
                            dragArea.pendingDrag = false;
                            for (var i = 0; i < root.orderedMonitors.length; i++) {
                                var c = chipRepeater.itemAt(i);
                                if (!c)
                                    continue;
                                var p = c.mapToItem(chipFlow, 0, 0);
                                if (mouse.x >= p.x && mouse.x <= p.x + c.width && mouse.y >= p.y && mouse.y <= p.y + c.height) {
                                    dragArea.draggedIndex = i;
                                    dragArea.pendingDrag = true;
                                    mouse.accepted = true;
                                    return;
                                }
                            }
                            mouse.accepted = false;
                        }

                        onPositionChanged: function (mouse) {
                            if (!dragArea.pendingDrag)
                                return;
                            var dx = mouse.x - dragArea.startPos.x;
                            var dy = mouse.y - dragArea.startPos.y;
                            if (!dragArea.dragging && Math.hypot(dx, dy) > dragArea.threshold) {
                                dragArea.dragging = true;
                                var item = chipRepeater.itemAt(dragArea.draggedIndex);
                                ghostLabel.text = item ? item.modelData : "";
                                dropGhost.visible = true;
                            }
                            if (!dragArea.dragging)
                                return;
                            dropGhost.x = mouse.x - dropGhost.width / 2;
                            dropGhost.y = mouse.y - dropGhost.height / 2 - 4;
                            var newDrop = dragArea.computeDropIndex(mouse.x, mouse.y);
                            dragArea.dropTargetIndex = newDrop;
                            var count = root.orderedMonitors.length;
                            if (newDrop >= 0) {
                                var ref = chipRepeater.itemAt(Math.min(newDrop, count - 1));
                                if (ref) {
                                    var rp = ref.mapToItem(chipFlow, 0, 0);
                                    dropIndicator.x = newDrop < count ? rp.x - dropIndicator.width - 2 : rp.x + ref.width + 2;
                                    dropIndicator.y = rp.y + (ref.height - dropIndicator.height) / 2;
                                }
                            }
                        }

                        onReleased: {
                            if (dragArea.dragging) {
                                var to = dragArea.dropTargetIndex;
                                if (to !== -1 && to !== dragArea.draggedIndex)
                                    root.applyMonitorReorder(dragArea.draggedIndex, to);
                            } else if (dragArea.pendingDrag) {
                                var released = chipRepeater.itemAt(dragArea.draggedIndex);
                                if (released)
                                    root.toggleMonitor(released.modelData);
                            }
                            dragArea.reset();
                        }

                        onCanceled: dragArea.reset()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "transparent"

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }

                    GradientStop {
                        position: 0.1
                        color: Config.cOutline
                    }

                    GradientStop {
                        position: 0.9
                        color: Config.cOutline
                    }

                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }

            // Layout grid
            Flow {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Config.spacingS

                Repeater {
                    model: root.layouts

                    delegate: Rectangle {
                        id: layoutBtn

                        required property var modelData
                        required property int index

                        readonly property bool active: {
                            if (root.selectedMonitors.length === 0)
                                return modelData.code === root.activeLayout;
                            if (root.selectedMonitors.length === 1)
                                return modelData.code === (layoutState.monitorLayouts[root.selectedMonitors[0]] || "");
                            return false;
                        }
                        property bool hovered: false
                        readonly property bool isFocused: (root.lastFocusMethod === "keyboard" && index === root.keyboardFocusedIndex) || hovered

                        width: (Config.panelWidth - Config.panelMargin * 2 - Config.spacingS * 2) / 3
                        height: Config.layoutBtnHeight
                        radius: Config.layoutBtnRadius
                        color: active ? Config.cPrimary : Config.cSurfaceVariant
                        border.width: isFocused && !active ? 2 : 1
                        border.color: active ? Config.cPrimary : isFocused ? Config.cPrimary : Config.cOutline

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.icon(root.iconMap[modelData.code] || "")
                                font.family: iconFont.name
                                font.pixelSize: Config.layoutIconSize
                                color: layoutBtn.active ? Config.cFgPrimary : Config.cFgSurface
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.name
                                font.pixelSize: Config.layoutLabelSize
                                font.weight: Font.Medium
                                color: layoutBtn.active ? Config.cFgPrimary : Config.cFgSurface
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                layoutBtn.hovered = true;
                                root.lastFocusMethod = "hover";
                            }
                            onExited: layoutBtn.hovered = false
                            onClicked: root.applyLayout(modelData.code)
                        }
                    }
                }
            }
        }
    }
}
