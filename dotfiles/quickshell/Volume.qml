// Default audio sink volume. Scroll to change, click to toggle mute.
import QtQuick
import Quickshell.Services.Pipewire
import Stylix

Item {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int percent: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    // Binds the sink so its volume properties stay live.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: {
            if (!root.sink)
                return "󰖁  n/a";
            if (root.muted)
                return "󰝟  muted";
            if (root.percent >= 60)
                return `󰕾  ${root.percent}%`;
            if (root.percent >= 20)
                return `󰖀  ${root.percent}%`;
            return `󰕿  ${root.percent}%`;
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: root.muted ? Theme.muted : Theme.foreground
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onClicked: {
            if (root.sink && root.sink.audio)
                root.sink.audio.muted = !root.sink.audio.muted;
        }

        onWheel: wheel => {
            if (!root.sink || !root.sink.audio)
                return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }
}
