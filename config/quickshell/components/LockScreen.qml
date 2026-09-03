pragma ComponentBehavior: Bound

// Secure Wayland session lock. Compositor-owned lock surfaces cover every
// output, so shell failure cannot expose applications underneath.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import Stylix
import "../services"

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
        PanelService.closeActive();
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
            color: Theme.base00

            onVisibleChanged: if (visible)
                Qt.callLater(() => prompt.input.forceActiveFocus())

            AuthPrompt {
                id: prompt
                anchors.fill: parent
                error: root.errorText.length > 0
                inputEnabled: !root.authenticating
                text: root.password
                onTextChanged: root.password = text
                onAccepted: root.submit()
                onKeyPressed: event => {
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
