pragma ComponentBehavior: Bound

// Secure Wayland session lock.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "../services"

Scope {
    id: root

    property string password: ""
    property string pendingPassword: ""
    property string errorText: ""
    property bool authenticating: false
    property bool pamAvailable: false
    readonly property bool locked: sessionLock.locked

    // Plain properties don't survive Quickshell's live reload.
    PersistentProperties {
        id: persist
        reloadableId: "lockScreenAutoLock"
        property bool autoLockHandled: false

        onLoaded: {
            if (persist.autoLockHandled)
                return;
            persist.autoLockHandled = true;
            // Lock in-process when launched as the real session shell (QS_AUTOLOCK=1, set by the systemd service).
            if (Quickshell.env("QS_AUTOLOCK") === "1"
                    && Quickshell.env("QS_DEV_NO_AUTOLOCK") !== "1")
                root.lock();
        }
    }

    function lock(): void {
        // Fired as early as possible so the compositor grabs the session lock before anything else gets a frame.
        if (sessionLock.locked) return;
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
        if (!pamAvailable) {
            password = "";
            errorText = "PAM CONFIG MISSING \u2014 CANNOT UNLOCK";
            return;
        }
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
        onLoadFailed: {
            root.pamAvailable = false;
            // Resolves after lock() already ran — surface the fail-closed message once we actually know, instead of guessing at lock time.
            if (root.locked) root.errorText = "PAM CONFIG MISSING \u2014 CANNOT UNLOCK";
        }
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
                dimBackground: true
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
