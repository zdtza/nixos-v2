// Date and time, updated once per minute.
import QtQuick
import Quickshell
import Stylix

Text {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    text: Qt.formatDateTime(clock.date, "dddd HH:mm")
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    color: Theme.foreground
}
