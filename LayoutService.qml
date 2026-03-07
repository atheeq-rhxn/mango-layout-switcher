pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var monitorLayouts: ({})
    property var availableLayouts: []
    property var availableMonitors: []

    signal layoutChanged(monitor: string, layout: string)
    signal layoutsReady()
    signal monitorsReady()

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

    function getLayoutName(code: string): string {
        return layoutNames[code]
            || code.replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    }

    function updateLayout(monitor: string, layout: string) {
        const clean = layout ? layout.trim() : "";
        if (!clean || !monitor || monitorLayouts[monitor] === clean) return;
        monitorLayouts[monitor] = clean;
        monitorLayoutsChanged();
        root.layoutChanged(monitor, clean);
    }

    function setLayout(monitorName: string, layoutCode: string) {
        if (!monitorName || !layoutCode) return;
        Quickshell.execDetached(["mmsg", "-o", monitorName, "-s", "-l", layoutCode]);
        updateLayout(monitorName, layoutCode);
    }

    function setLayoutGlobally(layoutCode: string) {
        availableMonitors.forEach(m => setLayout(m, layoutCode));
    }

    function init() {
        eventWatcher.running = true;
        layoutsQuery.running = true;
        monitorsQuery.running = true;
    }

    Process {
        id: eventWatcher

        command: ["mmsg", "-w"]
        running: false

        stdout: SplitParser {
            onRead: function(line: string) {
                const m = line.match(/^(\S+)\s+layout\s+(\S+)$/);
                if (m) root.updateLayout(m[1], m[2]);
            }
        }
    }

    Process {
        id: layoutsQuery

        property var tempArray: []

        command: ["mmsg", "-L"]
        running: false

        stdout: SplitParser {
            onRead: function(line: string) {
                const code = line.trim();
                if (code && !layoutsQuery.tempArray.some(l => l.code === code)) {
                    layoutsQuery.tempArray.push({ code: code, name: root.getLayoutName(code) });
                }
            }
        }

        onExited: function(exitCode: int) {
            if (exitCode === 0) {
                root.availableLayouts = tempArray;
                tempArray = [];
                root.layoutsReady();
            }
        }
    }

    Process {
        id: monitorsQuery

        property var tempArray: []

        command: ["mmsg", "-O"]
        running: false

        stdout: SplitParser {
            onRead: function(line: string) {
                const m = line.trim();
                if (m && !monitorsQuery.tempArray.includes(m)) {
                    monitorsQuery.tempArray.push(m);
                }
            }
        }

        onExited: function(exitCode: int) {
            if (exitCode === 0) {
                root.availableMonitors = tempArray;
                tempArray = [];
                root.monitorsReady();
            }
        }
    }
}
