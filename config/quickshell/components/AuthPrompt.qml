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
        color: Utils.alpha(Theme.base00, root.showWallpaper ? 0.35 : 0.55)
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(360, parent.width - 48)
        height: 48
        radius: PanelService.rounding
        color: Utils.alpha(Theme.base01, 0.95)
        border.width: 2
        border.color: root.error ? Theme.base08
            : (passwordInput.activeFocus ? Theme.base04 : Theme.base03)
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
            color: Theme.base05
            selectionColor: Theme.base02
            selectedTextColor: Theme.base05
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(22)
            font.letterSpacing: 2
            onAccepted: root.accepted()
            Keys.onPressed: event => root.keyPressed(event)
        }
    }
}
