import QtQuick
import QtQuick.Effects

// Everything the lock screen draws: wallpaper, dim, clock and the password dots.
// Takes every colour, path and font from its owner (LockScreen), which holds the password and PAM state.
Item {
    id: root

    // Theme inputs: base16 slots chosen by the owner.
    property color dimColor
    property color clockColor
    property color dotColor
    property color failColor
    property color successColor
    property url wallpaper
    property string fontFamily
    property date date: new Date()

    // Config.
    property real dimOpacity: 0.42
    property real blurRadius: 0
    property real clockSize: 200
    property bool clockShadow: false
    property LockMotion timing: LockMotion {}

    // idle | typing | checking | fail | success
    property string phase: "idle"
    property int dotCount: 0

    // The unlock transition finished; the owner can release the lock.
    signal unlockFinished()
    // The lock transition finished; the visual is at rest.
    signal appearFinished()

    readonly property bool designed: timing.designed

    // How far the lock is out of view: 1 is the plain desktop wallpaper, 0 the resting lock screen. Split so
    // content and backdrop can run on different durations. Starts out of view and animates in (appear()).
    property real contentOut: 1
    property real backdropOut: 1
    // The desktop shows the wallpaper slightly zoomed in (Theme.wallpaperZoom); the lock rests at 1 so it reads
    // as zoomed out, and zooms back in to match the desktop exactly as it goes away.
    property real desktopZoom: 1
    // false starts already at rest (for the unlock copy that replaces a live lock) instead of animating in.
    property bool animateIn: true

    function withAlpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Restarted explicitly so repeated fails replay even though no property changes.
    function fail(): void {
        indicator.fail();
    }

    function unlock(): void {
        unlockTransition.restart();
    }

    // Zoom out from the desktop wallpaper into the lock screen.
    function appear(): void {
        unlockTransition.stop();
        contentOut = 1;
        backdropOut = 1;
        lockTransition.restart();
    }

    // Jump straight to rest, for a lock surface taking over from a copy that already played the transition.
    function rest(): void {
        lockTransition.stop();
        unlockTransition.stop();
        contentOut = 0;
        backdropOut = 0;
    }

    function reset(): void {
        appear();
        indicator.resetShake();
    }

    Image {
        id: wallpaperImage
        anchors.fill: parent
        source: root.wallpaper
        fillMode: Image.PreserveAspectCrop
        cache: true
        scale: 1 + (root.desktopZoom - 1) * root.backdropOut
        layer.enabled: root.blurRadius > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1
            blurMax: root.blurRadius
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.dimColor
        opacity: root.dimOpacity * (1 - root.backdropOut)
    }

    // Centre column: clock, 48 px gap, indicator row.
    Column {
        id: content

        anchors.centerIn: parent
        spacing: 48
        opacity: 1 - root.contentOut
        scale: root.designed ? 1 + 0.04 * root.contentOut : 1
        transform: Translate { y: root.designed ? -40 * root.contentOut : 0 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(root.date, "hh:mm")
            color: root.clockColor
            font.family: root.fontFamily
            font.pixelSize: root.clockSize
            font.weight: Font.Bold
            font.letterSpacing: -0.02 * root.clockSize
            // CSS line-height 0.95: a multiple of the font size, not of the font's own taller line box.
            lineHeightMode: Text.FixedHeight
            lineHeight: 0.95 * root.clockSize
            layer.enabled: root.clockShadow
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.dimColor
                shadowOpacity: 0.35
                shadowBlur: 1
                blurMax: 24
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 2
            }
        }

        PasswordDots {
            id: indicator
            anchors.horizontalCenter: parent.horizontalCenter
            timing: root.timing
            dotColor: root.dotColor
            failColor: root.failColor
            successColor: root.successColor
            phase: root.phase
            dotCount: root.dotCount
        }
    }

    // Lock: the wallpaper zooms out and dims as the clock fades in.
    ParallelAnimation {
        id: lockTransition
        NumberAnimation {
            target: root; property: "contentOut"; to: 0
            duration: root.designed ? 500 : 250
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "backdropOut"; to: 0
            duration: root.designed ? 700 : 400
            easing.type: Easing.OutCubic
        }
        onFinished: root.appearFinished()
    }

    // Unlock: the clock fades (designed also lifts and grows it); the wallpaper zooms back in to full size
    // and undims, so the last frame is the plain desktop wallpaper.
    ParallelAnimation {
        id: unlockTransition
        NumberAnimation {
            target: root; property: "contentOut"; to: 1
            duration: root.designed ? 700 : 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "backdropOut"; to: 1
            duration: root.designed ? 900 : 400
            easing.type: Easing.OutCubic
        }
        onFinished: root.unlockFinished()
    }

    Component.onCompleted: {
        if (animateIn) {
            appear();
        } else {
            contentOut = 0;
            backdropOut = 0;
        }
    }
}
