import QtQuick
import "../services"
import ".."

// Shared visual shell for lock-screen and Polkit authentication.
Item {
    id: root

    property bool error: false
    property bool inputEnabled: true
    property bool responseVisible: false
    property bool showWallpaper: true
    // Independent of showWallpaper: Polkit's window is fully transparent and
    // relies on this dim scrim alone to darken the desktop behind it. The
    // lock screen has its own opaque background already, so it opts out.
    property bool dimBackground: true
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
        visible: root.dimBackground
        color: Utils.alpha(Theme.base00, root.showWallpaper ? 0.35 : Utils.scrimOpacity)
    }

    // Clicking the scrim (or anything else on the overlay) must not leave the
    // user typing into nothing: every press outside the field bounces focus
    // back to it. The field sits above this area and keeps its own handling.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: passwordInput.forceActiveFocus()
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(360, parent.width - 48)
        height: 48
        radius: PanelService.rounding
        color: Utils.alpha(Theme.base01, 0.95)
        border.width: 2
        // Same idle/focus pair as NetworkPanel's password field, so the
        // border reads as a field outline rather than an accent highlight.
        // Focus alone is not a signal here (the prompt always holds it), so
        // the border lights up on the first character instead.
        // Error stays full base08 -- it has to be noticed.
        // Checking disables the field, which dims the border again -- the
        // dots stay put, so the outline is what says "not your turn".
        border.color: root.error ? Theme.base08
            : (root.inputEnabled && passwordInput.text.length > 0 ? Theme.base04
                : Utils.alpha(Theme.base05, 0.4))

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
            // Dots are the only feedback needed; a blinking caret in a
            // centered password field just jitters the layout. An empty
            // delegate is the only reliable hide: TextInput re-asserts
            // cursorVisible itself on every focus change.
            cursorDelegate: Item {}
            color: Theme.base05
            selectionColor: Theme.base02
            selectedTextColor: Theme.base05
            font.family: Theme.monospace
            font.pixelSize: Utils.scaledFont(22)
            font.letterSpacing: 2
            onAccepted: root.accepted()
            // Anything that steals focus while the prompt is up gives it back.
            onActiveFocusChanged: if (!activeFocus && enabled)
                Qt.callLater(() => passwordInput.forceActiveFocus())
            Keys.onPressed: event => {
                if (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier) {
                    passwordInput.text = "";
                    event.accepted = true;
                    return;
                }
                root.keyPressed(event);
            }
        }
    }
}
