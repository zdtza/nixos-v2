pragma ComponentBehavior: Bound

// Secure Wayland session lock, and the login screen: greetd auto-logs in and this locks on the first
// Quickshell start of each Hyprland instance, before the desktop is ever shown. Password, phase and PAM
// live here so every screen mirrors the same feedback; LockVisual draws it. No text is ever shown.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "../../services"

Scope {
    id: root

    property string password: ""
    property string pendingPassword: ""
    // idle | typing | checking | fail | success
    property string phase: "idle"
    property bool pamAvailable: false
    readonly property bool locked: sessionLock.locked
    readonly property bool accepting: phase === "idle" || phase === "typing"
    // The login lock fades in from the black Hyprland starts on; later locks appear directly.
    property bool fromBlack: false

    // Every surface replays its shake on each fail.
    signal failed()
    signal resetRequested()
    signal settleRequested()

    function lock(): void {
        // Request the compositor's secure session lock.
        if (sessionLock.locked) return;
        revealing = false;
        concealing = false;
        password = "";
        pendingPassword = "";
        phase = "idle";
        resetRequested();
        PanelService.closeActive();
        sessionLock.locked = true;
        lockState.setText("locked");
    }

    // Interactive lock (Super+L): a copy of the lock fades in over the desktop as it zooms out, then the real
    // lock engages beneath it at rest. The copy holds exclusive keyboard focus and blocks clicks meanwhile.
    // Sleep and login use the instant lock() so they never wait on an animation.
    property bool concealing: false

    function lockAnimated(): void {
        if (sessionLock.locked || concealing)
            return;
        revealing = false;
        password = "";
        pendingPassword = "";
        phase = "idle";
        PanelService.closeActive();
        concealing = true;
    }

    function finishConceal(): void {
        if (!concealing || sessionLock.locked)
            return;
        settleRequested();
        sessionLock.locked = true;
        lockState.setText("locked");
        // The copy is hidden behind the lock from here; drop it once the lock surfaces are up.
        concealDrop.restart();
    }

    Timer {
        id: concealDrop
        interval: 200
        onTriggered: root.concealing = false
    }

    function setPassword(text: string): void {
        if (!accepting)
            return;
        password = text;
        phase = text.length > 0 ? "typing" : "idle";
    }

    function submit(): void {
        if (!sessionLock.locked || !accepting)
            return;
        // Empty Enter and a missing PAM config both fail closed with the same feedback.
        if (password.length === 0 || !pamAvailable) {
            fail();
            return;
        }
        pendingPassword = password;
        phase = "checking";
        if (!pam.start())
            fail();
    }

    function fail(): void {
        pendingPassword = "";
        phase = "fail";
        failed();
        failClear.restart();
    }

    // The lock hides the desktop until it is released, so the unlock can't play on the lock itself and reveal
    // the desktop at the same time. Instead a click-through copy of the lock (same visual, resting state) maps
    // over every screen on success, hidden behind the lock. When the success hold ends the lock is released
    // beneath it, invisibly, and the copy plays the unlock: its opacity follows the wallpaper zoom, so the
    // desktop fades in exactly as the zoom runs.
    property bool revealing: false
    // Backdrop progress of whichever copy is playing (1 = plain desktop wallpaper). The desktop wallpaper
    // follows it, so the copy and the wallpaper beneath it are the same size on every frame of the fade.
    property real copyBackdrop: 1

    Binding {
        target: Theme
        property: "wallpaperScale"
        value: 1 + (Theme.wallpaperZoom - 1) * root.copyBackdrop
        when: root.revealing || root.concealing
    }

    // Dot count frozen at success, so the copy matches the lock while the password is cleared.
    property int revealDots: 0

    signal revealStarted()

    function release(): void {
        sessionLock.locked = false;
        lockState.setText("unlocked");
        enableDesktopBinds.running = true;
        fromBlack = false;
        password = "";
        phase = "idle";
        revealStarted();
    }

    Variants {
        model: root.concealing ? Quickshell.screens : []

        PanelWindow {
            required property var modelData

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:lock-conceal"
            WlrLayershell.layer: WlrLayer.Overlay
            // Nothing reaches the desktop while it fades out.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            LockVisual {
                anchors.fill: parent
                // Fades in exactly as the wallpaper zooms out.
                opacity: 1 - backdropOut
                timing: lockMotion
                dimColor: Theme.base01
                clockColor: Theme.base06
                dotColor: Theme.base05
                failColor: Theme.base08
                successColor: Theme.base07
                wallpaper: Theme.wallpaper
                desktopZoom: Theme.wallpaperZoom
                fontFamily: Theme.monospace
                date: clock.date
                onBackdropOutChanged: root.copyBackdrop = backdropOut
                onAppearFinished: root.finishConceal()
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.BlankCursor
            }
        }
    }

    Variants {
        model: root.revealing ? Quickshell.screens : []

        PanelWindow {
            required property var modelData

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:unlock-reveal"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            // Click-through: the desktop is usable while it fades in.
            mask: Region {}

            LockVisual {
                id: revealVisual
                anchors.fill: parent
                // Starts at rest, identical to the lock it replaces, instead of animating in.
                animateIn: false
                opacity: 1 - backdropOut
                timing: lockMotion
                dimColor: Theme.base01
                clockColor: Theme.base06
                dotColor: Theme.base05
                failColor: Theme.base08
                successColor: Theme.base07
                wallpaper: Theme.wallpaper
                desktopZoom: Theme.wallpaperZoom
                fontFamily: Theme.monospace
                date: clock.date
                phase: "success"
                dotCount: root.revealDots
                onBackdropOutChanged: root.copyBackdrop = backdropOut
                onUnlockFinished: root.revealing = false
            }

            Connections {
                target: root

                function onRevealStarted(): void {
                    revealVisual.unlock();
                }
            }
        }
    }

    // Per-Hyprland-instance lock state ("locked" / "unlocked"). Missing means this is the session's first
    // Quickshell start, so lock it as the login screen; "locked" means a previous instance died while
    // locked, so take the lock back (Hyprland's misc.allow_session_lock_restore permits this).
    // Locking waits for this async load: locking during component completion breaks the Wayland connection.
    FileView {
        id: lockState
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-lock-${Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")}`
        preload: true
        printErrors: false
        onLoaded: {
            if (text().trim() !== "unlocked")
                root.lock();
            root.stateResolved = true;
        }
        onLoadFailed: {
            root.fromBlack = true;
            root.lock();
            root.stateResolved = true;
        }
    }

    // The desktop (bar, wallpaper; shell.qml) is only created once it can't be seen before the lock: the lock
    // state is known and either no lock is needed or the compositor has confirmed it. Latched, so later locks
    // keep the bar alive.
    property bool stateResolved: false
    property bool desktopReady: false

    function updateDesktopReady(): void {
        if (stateResolved && (!sessionLock.locked || sessionLock.secure))
            desktopReady = true;
    }

    onStateResolvedChanged: updateDesktopReady()

    Connections {
        target: sessionLock

        function onSecureChanged(): void {
            root.updateDesktopReady();
        }
    }

    // Hyprland registers desktop keybinds only after this session's first unlock (hyprland.lua, bind()).
    // Write that marker and reload once; later unlocks find it and leave the config alone.
    Process {
        id: enableDesktopBinds
        command: ["sh", "-c", "[ -e \"$1\" ] || { touch \"$1\" && hyprctl reload; }", "sh",
            `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-unlocked-${Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")}`]
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    LockMotion {
        id: lockMotion
    }

    Timer {
        id: failClear
        interval: lockMotion.failClear
        onTriggered: {
            root.phase = "idle";
            root.password = "";
        }
    }

    Timer {
        id: successHold
        interval: lockMotion.successHold
        onTriggered: root.release()
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

        // Interactive lock with the desktop fading out; sleep hooks keep using activate().
        function animate(): void {
            root.lockAnimated();
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
            root.pendingPassword = "";
            if (result === PamResult.Success) {
                root.phase = "success";
                // Map the unlock copy now, behind the lock, so it is ready when the hold ends.
                root.revealDots = root.password.length;
                root.revealing = true;
                successHold.restart();
            } else {
                root.fail();
            }
        }

        onError: root.fail()
    }

    WlSessionLock {
        id: sessionLock

        WlSessionLockSurface {
            color: Theme.base01

            onVisibleChanged: if (visible)
                Qt.callLater(() => passwordInput.forceActiveFocus())

            LockVisual {
                id: visual
                anchors.fill: parent
                timing: lockMotion
                dimColor: Theme.base01
                clockColor: Theme.base06
                dotColor: Theme.base05
                failColor: Theme.base08
                successColor: Theme.base07
                wallpaper: Theme.wallpaper
                desktopZoom: Theme.wallpaperZoom
                fontFamily: Theme.monospace
                date: clock.date
                phase: root.phase
                dotCount: root.password.length
                // Taking over from the conceal copy, which already played the transition.
                animateIn: !root.concealing
            }

            Connections {
                target: root

                function onFailed(): void {
                    visual.fail();
                }

                function onResetRequested(): void {
                    visual.reset();
                }

                function onSettleRequested(): void {
                    visual.rest();
                }

                // Mirror resets and other screens' typing into this screen's field.
                function onPasswordChanged(): void {
                    if (passwordInput.text !== root.password)
                        passwordInput.text = root.password;
                }

                function onPhaseChanged(): void {
                    if (root.phase === "idle")
                        passwordInput.forceActiveFocus();
                }
            }

            // Invisible but focused; fills the surface so any click lands on it.
            TextInput {
                id: passwordInput
                anchors.fill: parent
                opacity: 0
                echoMode: TextInput.Password
                cursorVisible: false
                readOnly: !root.accepting
                Accessible.name: "Password"
                Accessible.role: Accessible.EditableText
                Accessible.passwordEdit: true
                onTextChanged: root.setPassword(text)
                onAccepted: root.submit()
                // Anything that steals focus while locked gives it back.
                onActiveFocusChanged: if (!activeFocus)
                    Qt.callLater(() => passwordInput.forceActiveFocus())
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape
                        || (event.key === Qt.Key_C && event.modifiers === Qt.ControlModifier)) {
                        root.setPassword("");
                        event.accepted = true;
                    }
                }
            }

            // Picks up from the black Hyprland starts on (misc.background_color) at login.
            Rectangle {
                anchors.fill: parent
                color: "black"
                visible: root.fromBlack && opacity > 0

                NumberAnimation on opacity {
                    running: root.fromBlack
                    from: 1
                    to: 0
                    duration: lockMotion.loginFade
                    easing.type: Easing.InOutSine
                }
            }

            // Hide the pointer everywhere; no buttons accepted, so clicks still reach the field.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.BlankCursor
            }
        }
    }
}
