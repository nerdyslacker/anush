import QtQuick
import "../.."
import Quickshell
import Quickshell.Io

// Date + 12-hour time, with a middle-click compact-time toggle, the calendar
// popup on left click, and renCal on right click when it is installed.
BarModule {
    id: root

    property bool hasRenCal: false
    property bool timeOnly: false
    readonly property string timeText: Qt.formatDateTime(clock.date, "h:mm AP")
    readonly property string dateText: Qt.formatDateTime(clock.date, "ddd MMM d")

    compactIcon: "󰥔"
    compactLabel: Qt.formatDateTime(clock.date, "HH:mm")

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    label: timeOnly ? timeText : dateText + "  " + timeText
    tooltip: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy  h:mm:ss AP")

    onClicked: mouse => {
        if (mouse.button === Qt.MiddleButton)
            timeOnly = !timeOnly
        else if (mouse.button === Qt.RightButton && hasRenCal)
            Quickshell.execDetached(["rencal"])
        else
            calendar.visible = !calendar.visible
    }

    Process {
        command: ["sh", "-c", "command -v rencal 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.hasRenCal = text.trim() !== ""
        }
    }

    CalendarPopup {
        id: calendar
        anchorItem: root
    }
}
