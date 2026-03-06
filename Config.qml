pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root

  // Colors
  readonly property color cPrimary:        "#7aa2f7"
  readonly property color cFgPrimary:      "#16161e"
  readonly property color cSurface:        "#1a1b26"
  readonly property color cFgSurface:      "#c0caf5"
  readonly property color cSurfaceVariant: "#24283b"
  readonly property color cFgVariant:      "#9aa5ce"
  readonly property color cOutline:        "#353D57"

  // Panel
  readonly property int panelWidth:  316
  readonly property int panelRadius: 17
  readonly property int panelMargin: 12

  // Spacing
  readonly property int spacingL: 9
  readonly property int spacingM: 7
  readonly property int spacingS: 5

  // Font sizes
  readonly property int fsBase:  14
  readonly property int fsChip:  11
  readonly property int fsSmall: 10
  readonly property int fsTiny:  9

  // Component sizes
  readonly property int headerRadius:     13
  readonly property int headerPadding:    15
  readonly property int toggleWidth:      34
  readonly property int toggleHeight:     17
  readonly property int toggleKnob:       13
  readonly property int chipHeight:       27
  readonly property int chipRadius:       11
  readonly property int chipPadding:      14
  readonly property int layoutBtnHeight:  54
  readonly property int layoutBtnRadius:  13
  readonly property int layoutIconSize:   16
  readonly property int layoutLabelSize:  11
}
