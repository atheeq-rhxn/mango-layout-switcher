pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property real scaling: 1.0

    function sp(n: real): real {
        return Math.round(n * scaling);
    }

    function fs(n: real): real {
        return Math.round(n * Math.max(1.0, scaling * 0.9));
    }

    readonly property color cPrimary: "#7aa2f7"
    readonly property color cFgPrimary: "#16161e"
    readonly property color cSurface: "#1a1b26"
    readonly property color cFgSurface: "#c0caf5"
    readonly property color cSurfaceVariant: "#24283b"
    readonly property color cFgVariant: "#9aa5ce"
    readonly property color cOutline: "#353D57"

    readonly property real panelWidth: 280
    readonly property real panelRadius: 14
    readonly property real panelMargin: 9

    readonly property real spacingL: 7
    readonly property real spacingM: 5
    readonly property real spacingS: 4

    readonly property real fsBase: 14
    readonly property real fsChip: 11
    readonly property real fsSmall: 10
    readonly property real fsTiny: 9

    readonly property real headerRadius: 10
    readonly property real headerPadding: 11
    readonly property real toggleWidth: 28
    readonly property real toggleHeight: 14
    readonly property real toggleKnob: 10
    readonly property real chipHeight: 22
    readonly property real chipRadius: 9
    readonly property real chipPadding: 10
    readonly property real layoutBtnHeight: 44
    readonly property real layoutBtnRadius: 10
    readonly property real layoutIconSize: 16
    readonly property real layoutLabelSize: 11
}
