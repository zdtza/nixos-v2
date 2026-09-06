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

    // Plain properties don't survive Quickshell's live reload (it rebuilds
    // the engine in-process on config changes) -- PersistentProperties is
    // the type built for carrying a value across that, matched by
    // reloadableId rather than tree position. Without this, onCompleted
    // below re-locks on every reload, not just real process startup.
    PersistentProperties {
        id: persist
        reloadableId: "lockScreenAutoLock"
        property bool autoLockHandled: false
    }

    function lock(): void {
        // Fired as early as possible (see Component.onCompleted below) so
        // the compositor grabs the session lock before anything else gets a
        // frame on screen — don't gate this on the PAM check resolving,
        // that's a slower async file read and would just add to the flash
        // window. Fail-closed behavior lives in submit(): pamAvailable
        // defaults to false until the check resolves, so unlocking is
        // already blocked before we know either way.
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

    Component.onCompleted: {
        // Lock in-process the instant this component exists, when launched
        // as the real session shell (QS_AUTOLOCK=1, set by the systemd
        // service). No IPC round-trip, no poll-and-hope race, no waiting on
        // the async PAM file check below — grabbing the compositor lock as
        // early as possible is what keeps the desktop from flashing on
        // screen before it's covered. Manual `qs` debug runs don't set the
        // var, so they don't self-lock.
        if (persist.autoLockHandled) return;
        persist.autoLockHandled = true;
        // Manual escape hatch for editing this file live: `systemctl --user
        // set-environment QS_DEV_NO_AUTOLOCK=1 && systemctl --user restart
        // quickshell` before a dev session, unset + restart again when done.
        if (Quickshell.env("QS_AUTOLOCK") === "1"
                && Quickshell.env("QS_DEV_NO_AUTOLOCK") !== "1") lock();
    }

    FileView {
        path: "/etc/pam.d/quickshell"
        preload: true
        printErrors: false
        onLoaded: root.pamAvailable = true
        onLoadFailed: {
            root.pamAvailable = false;
            // Resolves after lock() already ran (fast local file read vs a
            // full QML engine boot) — surface the fail-closed message once
            // we actually know, instead of guessing at lock time.
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
