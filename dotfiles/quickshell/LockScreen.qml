pragma ComponentBehavior: Bound

// Secure Wayland session lock. Compositor-owned lock surfaces cover every
// output, so shell failure cannot expose applications underneath.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import Stylix

Scope {
    id: root

    property string password: ""
    property string pendingPassword: ""
    property string errorText: ""
    property bool authenticating: false
    property bool pamAvailable: false
    readonly property bool locked: sessionLock.locked

    function lock(): void {
        // Never enter a secure session lock without a usable authentication
        // policy: compositor intentionally cannot be bypassed if auth fails.
        if (sessionLock.locked || !pamAvailable) return;
        password = "";
        pendingPassword = "";
        errorText = "";
        authenticating = false;
        ServicePanel.closeActive();
        sessionLock.locked = true;
    }

    function submit(): void {
        if (!sessionLock.locked || authenticating || password.length === 0)
            return;
        pendingPassword = password;
        errorText = "";
        authenticating = true;
        if (!pam.start()) {
            authenticating = false;
            pendingPassword = "";
            errorText = "AUTHENTICATION UNAVAILABLE";
        }
    }

    FileView {
        path: "/etc/pam.d/quickshell"
        preload: true
        printErrors: false
        onLoaded: root.pamAvailable = true
        onLoadFailed: root.pamAvailable = false
    }

    IpcHandler {
        target: "lock"

        function activate(): void {
            root.lock();
        }

        function isLocked(): bool {
            return root.locked;
        }
    }

    PamContext {
        id: pam
        config: "quickshell"

        onResponseRequiredChanged: if (responseRequired)
            respond(root.pendingPassword)

        onCompleted: result => {
            root.authenticating = false;
            root.pendingPassword = "";
            root.password = "";
            if (result === PamResult.Success) {
                root.errorText = "";
                sessionLock.locked = false;
            } else {
                root.errorText = "INCORRECT PASSWORD";
            }
        }
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            id: lockSurface
            color: Theme.background

            onVisibleChanged: if (visible)
                Qt.callLater(() => passwordInput.forceActiveFocus())

            Image {
                id: wallpaper
                anchors.fill: parent
                source: Theme.wallpaper
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                layer.enabled: true
            }

            Rectangle {
                anchors.fill: parent
                color: Util.alpha(Theme.background, 0.45)
            }

            Column {
                anchors.centerIn: parent
                width: Math.min(360, parent.width - 48)
                spacing: 10

                Rectangle {
                    width: parent.width
                    height: 48
                    radius: ServicePanel.rounding
                    color: Util.alpha(Theme.dark_background, 0.88)
                    border.width: 2
                    border.color: root.errorText.length > 0 ? Theme.urgent
                        : (passwordInput.activeFocus ? Theme.muted : Theme.border)

                    TextInput {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        enabled: !root.authenticating
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: Theme.foreground
                        selectionColor: Theme.surface
                        selectedTextColor: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Util.scaledFont(22)
                        font.letterSpacing: 2
                        text: root.password
                        onTextChanged: root.password = text
                        onAccepted: root.submit()
                        Keys.onPressed: event => {
                            const clearInput = event.key === Qt.Key_Escape
                                || (event.key === Qt.Key_C
                                    && (event.modifiers & Qt.ControlModifier) !== 0);
                            if (clearInput) {
                                root.password = "";
                                root.errorText = "";
                                event.accepted = true;
                            }
                        }
                    }
                }
            }
        }
    }
}
