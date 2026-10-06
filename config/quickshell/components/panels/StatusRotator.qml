import QtQuick

// Fades hero status out, advances text, then fades it back in.
Item {
    id: root

    required property Item target
    property bool running: false
    property int interval: 6000

    signal advance()

    implicitWidth: 0
    implicitHeight: 0

    Timer {
        interval: root.interval
        running: root.running
        repeat: true
        onTriggered: phraseSwap.restart()
    }

    SequentialAnimation {
        id: phraseSwap

        NumberAnimation {
            target: root.target
            property: "opacity"
            to: 0
            duration: 180
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: root.advance()
        }
        NumberAnimation {
            target: root.target
            property: "opacity"
            to: 1
            duration: 260
            easing.type: Easing.InQuad
        }
    }
}
