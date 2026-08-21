// Default audio sink volume. Scroll to change, click to toggle mute.
import QtQuick
import Quickshell.Services.Pipewire
import Stylix

Item {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int percent: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

    // Binds the sink so its volume properties stay live.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: {
            if (!root.sink)
                return "󰖁 ";
            if (root.muted)
                return "󰝟 ";
            if (root.percent >= 60)
                return `󰕾`;
            if (root.percent >= 20)
                return `󰖀`;
            return `󰕿`;
        }
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        color: Theme.foreground
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
