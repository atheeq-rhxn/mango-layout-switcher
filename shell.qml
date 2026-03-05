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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "mango-layout-switcher"

    anchors { top: true; bottom: true; left: true; right: true }

    //  Style 
    readonly property int fsS:  10
    readonly property int fsM:  11
    readonly property int fsL:  13
    readonly property int fsXL: 16

    readonly property int rM: 16
    readonly property int rL: 20

    readonly property int borderS: 1
    readonly property int borderM: 2

    readonly property int mXXS: 2
    readonly property int mS:   6
    readonly property int mM:   9
    readonly property int mL:   13
    readonly property int m2M:  mM * 2
    readonly property int m2L:  mL * 2

    readonly property color cPrimary:        "#7aa2f7"
    readonly property color cFgPrimary:      "#16161e"
    readonly property color cSurface:        "#1a1b26"
    readonly property color cFgSurface:      "#c0caf5"
    readonly property color cSurfaceVariant: "#24283b"
    readonly property color cFgVariant:      "#9aa5ce"
    readonly property color cOutline:        "#353D57"
    readonly property color cHover:          "#9ece6a"

    //  Icons 
    FontLoader {
        id: iconFont
        source: Qt.resolvedUrl("Assets/Fonts/tabler/noctalia-tabler-icons.ttf")
    }

    readonly property var tablerIcons: ({
        "layout-grid":                "\u{edba}",
        "layout-sidebar":             "\u{eada}",
        "rectangle":                  "\u{ed37}",
        "carousel-horizontal":        "\u{f659}",
        "carousel-vertical":          "\u{f65a}",
        "layout-rows":                "\u{ead8}",
        "grid-dots":                  "\u{eaba}",
        "versions":                   "\u{ed52}",
        "layout-sidebar-right":       "\u{ead9}",
        "layout-distribute-vertical": "\u{ead6}",
        "layout-dashboard":           "\u{f02c}",
        "chart-funnel":               "\u{fef5}",
        "grip-vertical":              "\u{ec01}",
        "check":                      "\u{ea5e}"
    })

    readonly property var iconMap: ({
        "T":  "layout-sidebar",              "M":  "rectangle",
        "S":  "carousel-horizontal",         "G":  "layout-grid",
        "K":  "versions",                    "RT": "layout-sidebar-right",
        "CT": "layout-distribute-vertical",  "TG": "layout-dashboard",
        "VT": "layout-rows",                 "VS": "carousel-vertical",
        "VG": "grid-dots",                   "VK": "chart-funnel"
    })

    function icon(name) { return tablerIcons[name] || "" }

    //  Layout State 
    QtObject {
        id: layoutState

        property var monitorLayouts:    ({})
        property var availableLayouts:  []
        property var availableMonitors: []

        readonly property var layoutNames: ({
            "S": "Scroller",       "T": "Tile",               "G": "Grid",
            "M": "Monocle",        "K": "Deck",               "CT": "Center Tile",
            "RT": "Right Tile",    "VS": "Vertical Scroller", "VT": "Vertical Tile",
            "VG": "Vertical Grid", "VK": "Vertical Deck",     "TG": "Tgmix"
        })

        function getLayoutName(code) {
            return layoutNames[code]
                || code.replace(/_/g, " ").replace(/\b\w/g, function(c) { return c.toUpperCase() })
        }

        function updateLayout(monitor, layout) {
            const clean = layout ? layout.trim() : ""
            if (clean && monitor && monitorLayouts[monitor] !== clean) {
                monitorLayouts[monitor] = clean
                monitorLayoutsChanged()
            }
        }

        function setLayout(monitorName, layoutCode) {
            if (!monitorName || !layoutCode) return
            Quickshell.execDetached(["mmsg", "-o", monitorName, "-s", "-l", layoutCode])
            updateLayout(monitorName, layoutCode)
        }

        function setLayoutGlobally(layoutCode) {
            availableMonitors.forEach(function(m) { setLayout(m, layoutCode) })
        }
    }

    //  Processes 
    Process {
        id: eventWatcher
        command: ["mmsg", "-w"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                const match = line.match(/^(\S+)\s+layout\s+(\S+)$/)
                if (match) layoutState.updateLayout(match[1], match[2])
            }
        }
    }

    Process {
        id: layoutsQuery
        command: ["mmsg", "-L"]
        running: true
        property var tempArray: []
        stdout: SplitParser {
            onRead: function(line) {
                const code = line.trim()
                if (code && !layoutsQuery.tempArray.some(function(l) { return l.code === code }))
                    layoutsQuery.tempArray.push({ "code": code, "name": layoutState.getLayoutName(code) })
            }
        }
        onExited: function(exitCode) {
            if (exitCode === 0) layoutState.availableLayouts = tempArray
        }
    }

    Process {
        id: monitorsQuery
        command: ["mmsg", "-O"]
        running: true
        property var tempArray: []
        stdout: SplitParser {
            onRead: function(line) {
                const m = line.trim()
                if (m && !monitorsQuery.tempArray.includes(m))
                    monitorsQuery.tempArray.push(m)
            }
        }
        onExited: function(exitCode) {
            if (exitCode === 0) layoutState.availableMonitors = tempArray
        }
    }

    //  App State 
    property var savedMonitorOrder: []

    property var orderedMonitors: {
        const all   = layoutState.availableMonitors
        const order = savedMonitorOrder
        if (!order.length) return all
        return order.filter(function(m) { return all.indexOf(m) !== -1 })
            .concat(all.filter(function(m) { return order.indexOf(m) === -1 }))
    }

    function applyMonitorReorder(fromIndex, toIndex) {
        if (fromIndex === toIndex) return
        const arr = orderedMonitors.slice()
        arr.splice(toIndex, 0, arr.splice(fromIndex, 1)[0])
        savedMonitorOrder = arr
    }

    readonly property string panelMonitor: orderedMonitors.length > 0 ? orderedMonitors[0] : ""
    readonly property var    layouts:      layoutState.availableLayouts
    readonly property string activeLayout: {
        const mon = selectedMonitors.length > 0 ? selectedMonitors[0] : panelMonitor
        return layoutState.monitorLayouts[mon] || ""
    }

    property bool applyToAll: false
    property var  selectedMonitors: []

    readonly property real panelWidth:  360
    readonly property real panelHeight: panelContent.implicitHeight + root.m2L

    function toggleMonitor(name) {
        selectedMonitors = selectedMonitors.includes(name)
            ? selectedMonitors.filter(function(m) { return m !== name })
            : selectedMonitors.concat([name])
    }

    function applyLayout(code) {
        if (applyToAll)
            layoutState.setLayoutGlobally(code)
        else if (selectedMonitors.length > 0)
            selectedMonitors.forEach(function(m) { layoutState.setLayout(m, code) })
        else
            layoutState.setLayout(panelMonitor, code)
    }

    //  UI 
    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }

    Rectangle {
        anchors.centerIn: parent
        width:  root.panelWidth
        height: root.panelHeight
        color:  root.cSurface
        radius: root.rL
        border { width: root.borderS; color: root.cOutline }

        MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
        }

        ColumnLayout {
            id: panelContent
            anchors { fill: parent; margins: root.mL }
            spacing: root.mM

            // Header
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight + root.m2M
                color:  root.cSurfaceVariant
                radius: root.rM

                RowLayout {
                    id: headerRow
                    anchors.centerIn: parent
                    width: parent.width - root.m2M
                    spacing: root.mM

                    Text {
                        text: root.icon("layout-grid")
                        font.family:    iconFont.name
                        font.pixelSize: root.fsXL
                        color: root.cPrimary
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        text: "Switch Layout"
                        font.pixelSize: root.fsXL
                        font.weight:    Font.Bold
                        color: root.cFgSurface
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Apply-to-all toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: root.mM

                Text {
                    text: "Apply to all monitors"
                    font.pixelSize: root.fsL
                    font.weight:    Font.Medium
                    color: root.cFgVariant
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    id: toggler
                    readonly property int sz: Math.round(root.rM * 0.8)
                    implicitWidth:  sz * 2
                    implicitHeight: sz
                    radius: height / 2
                    color: root.applyToAll ? root.cPrimary : root.cSurface
                    border { color: root.cOutline; width: root.borderS }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        readonly property int d: Math.round(toggler.sz * 0.8)
                        width: d; height: d; radius: d / 2
                        color: root.applyToAll ? root.cFgPrimary : root.cPrimary
                        border { color: root.cSurface; width: root.borderM }
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.applyToAll ? toggler.width - width - 3 : 3
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.applyToAll = !root.applyToAll
                            if (!root.applyToAll && root.selectedMonitors.length === 0)
                                root.selectedMonitors = [root.panelMonitor]
                        }
                    }
                }
            }

            // Monitor selector
            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.mS
                opacity: root.applyToAll ? 0.6 : 1.0
                enabled: !root.applyToAll

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.mS
                    Text {
                        text: "Select monitors"
                        font.pixelSize: root.fsL
                        font.weight:    Font.Medium
                        color: root.cFgVariant
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }
                    Text {
                        text: root.icon("grip-vertical")
                        font.family:    iconFont.name
                        font.pixelSize: root.fsS
                        color:   root.cFgVariant
                        opacity: 0.5
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Item {
                    id: dragArea
                    Layout.fillWidth: true
                    implicitHeight: chipFlow.implicitHeight

                    property int   draggedIndex:   -1
                    property int   dropTargetIndex: -1
                    property bool  dragging:    false
                    property bool  pendingDrag: false
                    property point startPos:    Qt.point(0, 0)
                    readonly property real threshold: 8

                    function chipRect(i) {
                        const chip = chipRepeater.itemAt(i)
                        if (!chip) return Qt.rect(0, 0, 0, 0)
                        const p = chip.mapToItem(chipFlow, 0, 0)
                        return Qt.rect(p.x, p.y, chip.width, chip.height)
                    }

                    function computeDropIndex(mx, my) {
                        const count = root.orderedMonitors.length
                        let best = draggedIndex, bestDist = Infinity
                        for (let i = 0; i < count; i++) {
                            if (i === draggedIndex) continue
                            const r = chipRect(i)
                            if (!r.width) continue
                            const dist = Math.hypot(mx - (r.x + r.width / 2), my - (r.y + r.height / 2))
                            if (dist < bestDist) {
                                bestDist = dist
                                best = mx < r.x + r.width / 2 ? i : i + 1
                            }
                        }
                        if (best > draggedIndex) best--
                        return Math.max(0, Math.min(count - 1, best))
                    }

                    function reset() {
                        draggedIndex = -1; dropTargetIndex = -1
                        dragging = false; pendingDrag = false
                        dropGhost.visible = false
                    }

                    Rectangle {
                        id: dropIndicator
                        width: 2; height: 36; radius: 1
                        color:   root.cPrimary
                        visible: dragArea.dragging && dragArea.dropTargetIndex !== -1
                        z: 10
                        SequentialAnimation on opacity {
                            running: dropIndicator.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 0.5; duration: 350; easing.type: Easing.InOutQuad }
                        }
                        Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    }

                    Rectangle {
                        id: dropGhost
                        width: ghostLabel.implicitWidth + root.m2M
                        height: 36; radius: root.rM
                        color: root.cPrimary; opacity: 0.85
                        visible: false; z: 20
                        Text {
                            id: ghostLabel
                            anchors.centerIn: parent
                            font.pixelSize: root.fsS
                            font.weight:    Font.Medium
                            color: root.cFgPrimary
                        }
                    }

                    Flow {
                        id: chipFlow
                        width: parent.width
                        spacing: root.mS

                        Repeater {
                            id: chipRepeater
                            model: root.orderedMonitors

                            delegate: Rectangle {
                                id: chip
                                required property int    index
                                required property string modelData

                                readonly property bool selected:     root.applyToAll || root.selectedMonitors.includes(modelData)
                                readonly property bool beingDragged: dragArea.draggedIndex === index && dragArea.dragging

                                width:  chipInner.implicitWidth + root.mM * 2
                                height: 36
                                radius: root.rM
                                color:  selected ? root.cPrimary : root.cSurfaceVariant
                                border { width: 2; color: selected ? root.cPrimary : root.cOutline }
                                opacity: beingDragged ? 0.35 : 1.0
                                scale:   beingDragged ? 0.95 : 1.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on scale   { NumberAnimation { duration: 150 } }

                                RowLayout {
                                    id: chipInner
                                    anchors.centerIn: parent
                                    spacing: root.mS

                                    Text {
                                        text: root.icon("grip-vertical")
                                        font.family:    iconFont.name
                                        font.pixelSize: root.fsS
                                        color:   chip.selected ? Qt.alpha(root.cFgPrimary, 0.6) : root.cFgVariant
                                        opacity: 0.7
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    Text {
                                        visible: chip.selected
                                        text: root.icon("check")
                                        font.family:    iconFont.name
                                        font.pixelSize: root.fsM
                                        color: root.cFgPrimary
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    Text {
                                        text: modelData
                                        font.pixelSize: root.fsS
                                        font.weight:    Font.Medium
                                        color: chip.selected ? root.cFgPrimary : root.cFgSurface
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
                        cursorShape:  dragArea.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                        onPressed: function(mouse) {
                            dragArea.startPos  = Qt.point(mouse.x, mouse.y)
                            dragArea.dragging  = false
                            dragArea.pendingDrag = false
                            for (let i = 0; i < root.orderedMonitors.length; i++) {
                                const c = chipRepeater.itemAt(i)
                                if (!c) continue
                                const p = c.mapToItem(chipFlow, 0, 0)
                                if (mouse.x >= p.x && mouse.x <= p.x + c.width &&
                                    mouse.y >= p.y && mouse.y <= p.y + c.height) {
                                    dragArea.draggedIndex = i
                                    dragArea.pendingDrag  = true
                                    mouse.accepted = true
                                    return
                                }
                            }
                            mouse.accepted = false
                        }

                        onPositionChanged: function(mouse) {
                            if (!dragArea.pendingDrag) return
                            const dx = mouse.x - dragArea.startPos.x
                            const dy = mouse.y - dragArea.startPos.y
                            if (!dragArea.dragging && Math.hypot(dx, dy) > dragArea.threshold) {
                                dragArea.dragging = true
                                const item = chipRepeater.itemAt(dragArea.draggedIndex)
                                ghostLabel.text  = item ? item.modelData : ""
                                dropGhost.visible = true
                            }
                            if (!dragArea.dragging) return
                            dropGhost.x = mouse.x - dropGhost.width  / 2
                            dropGhost.y = mouse.y - dropGhost.height / 2 - 4
                            const newDrop = dragArea.computeDropIndex(mouse.x, mouse.y)
                            dragArea.dropTargetIndex = newDrop
                            const count = root.orderedMonitors.length
                            if (newDrop >= 0) {
                                const ref = chipRepeater.itemAt(Math.min(newDrop, count - 1))
                                if (ref) {
                                    const rp = ref.mapToItem(chipFlow, 0, 0)
                                    dropIndicator.x = (newDrop < count)
                                        ? rp.x - dropIndicator.width - root.mXXS
                                        : rp.x + ref.width + root.mXXS
                                    dropIndicator.y = rp.y + (ref.height - dropIndicator.height) / 2
                                }
                            }
                        }

                        onReleased: {
                            if (dragArea.dragging) {
                                const to = dragArea.dropTargetIndex
                                if (to !== -1 && to !== dragArea.draggedIndex)
                                    root.applyMonitorReorder(dragArea.draggedIndex, to)
                            } else if (dragArea.pendingDrag) {
                                const released = chipRepeater.itemAt(dragArea.draggedIndex)
                                if (released) root.toggleMonitor(released.modelData)
                            }
                            dragArea.reset()
                        }

                        onCanceled: dragArea.reset()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: root.borderS
                color:  "transparent"
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.1; color: root.cOutline }
                    GradientStop { position: 0.9; color: root.cOutline }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Layout grid
            Flow {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.mS

                Repeater {
                    model: root.layouts
                    delegate: Rectangle {
                        id: layoutBtn
                        required property var modelData

                        width:  (root.panelWidth - root.mL * 2 - root.mS * 2) / 3
                        height: 64

                        readonly property bool active: {
                            if (root.selectedMonitors.length === 0)
                                return modelData.code === root.activeLayout
                            if (root.selectedMonitors.length === 1)
                                return modelData.code === (layoutState.monitorLayouts[root.selectedMonitors[0]] || "")
                            return false
                        }
                        property bool hovered: false

                        color:  active ? root.cPrimary : root.cSurfaceVariant
                        radius: root.rM

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color:   root.cHover
                            opacity: layoutBtn.hovered && !layoutBtn.active ? 0.2 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.icon(root.iconMap[modelData.code] || "")
                                font.family:    iconFont.name
                                font.pixelSize: root.fsXL
                                color: layoutBtn.active ? root.cFgPrimary : root.cFgSurface
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.name
                                font.pixelSize: root.fsM
                                font.weight:    Font.Medium
                                color: layoutBtn.active ? root.cFgPrimary : root.cFgSurface
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onEntered: layoutBtn.hovered = true
                            onExited:  layoutBtn.hovered = false
                            onClicked: root.applyLayout(modelData.code)
                        }
                    }
                }
            }
        }
    }
}
