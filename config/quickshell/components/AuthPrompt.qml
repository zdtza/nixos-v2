import QtQuick
import Stylix
import "../services"
import ".."

// Shared visual shell for lock-screen and Polkit authentication.
Item {
    id: root

    property bool error: false
    property bool inputEnabled: true
    property bool responseVisible: false
    property bool showWallpaper: true
    property alias text: passwordInput.text
    readonly property alias input: passwordInput

    signal accepted()
    signal keyPressed(var event)

    Image {
        anchors.fill: parent
        source: Theme.wallpaper
        visible: root.showWallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        layer.enabled: true
    }

    Rectangle {
        anchors.fill: parent
        color: Utils.alpha(Theme.background, root.showWallpaper ? 0.35 : 0.55)
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(360, parent.width - 48)
        height: 48
        radius: ServicePanel.rounding
        color: Utils.alpha(Theme.dark_background, 0.95)
        border.width: 2
        border.color: root.error ? Theme.urgent
            : (passwordInput.activeFocus ? Theme.muted : Theme.border)
        layer.enabled: true
        layer.effect: ShellShadow {}

        Behavior on border.color { ColorAnimation { duration: 120 } }

        TextInput {
            id: passwordInput
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            enabled: root.inputEnabled
            echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
            passwordCharacter: "●"
            color: Theme.foreground
            selectionColor: Theme.surface
            selectedTextColor: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Utils.scaledFont(22)
            font.letterSpacing: 2
            onAccepted: root.accepted()
            Keys.onPressed: event => root.keyPressed(event)
        }
    }
}
