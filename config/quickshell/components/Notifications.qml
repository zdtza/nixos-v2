pragma ComponentBehavior: Bound

// Freedesktop notification daemon and top-right notification stack.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Stylix
import "../services"
import ".."

Scope {
    id: root

    // Only the monitor *name* is cached, never a screen object. Quickshell's
    // reload preserves top-level property values across an engine rebuild,
    // but QuickshellScreenInfo/QScreen objects belong to the generation that
    // created them and get torn down on reload -- caching one directly here
    // caused a segfault (QWindow::setScreen on a freed screen) on the next
    // reload after any notification had arrived. Strings survive reload
    // safely; the live screen object is re-resolved from the current
    // generation's Quickshell.screens every time it's needed.
    property string targetScreenName: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

    function screenForMonitor(name: string): var {
        for (const screen of Quickshell.screens) {
            if (screen.name === name)
                return screen;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function focusedMonitorName(): string {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    function clearNotifications(): void {
        for (const notification of server.trackedNotifications.values)
            notification.dismiss();
    }

    Component.onCompleted: {
        if (DoNotDisturbService.enabled)
            Qt.callLater(root.clearNotifications);
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        // Senders (Teams in particular) check this capability before
        // deciding how to present a link. When it's false they assume we
        // can't render <a href>, so they fall back to appending the raw
        // URL as plain text into the body instead. Advertising support
        // here lets them send a real hyperlink (usually with friendly
        // link text) instead of concatenating the URL into the
        // description.
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: false
        inlineReplySupported: false

        onNotification: notification => {
            if (DoNotDisturbService.enabled) {
                notification.dismiss();
                return;
            }
            root.targetScreenName = root.focusedMonitorName();
            notification.tracked = true;
        }
    }

    Connections {
        target: DoNotDisturbService
        function onEnabledChanged(): void {
            if (DoNotDisturbService.enabled)
                root.clearNotifications();
        }
    }

    PanelWindow {
        id: window

        screen: root.screenForMonitor(root.targetScreenName)
        visible: !DoNotDisturbService.enabled
            && server.trackedNotifications.values.length > 0
        color: "transparent"
        implicitWidth: 450
        exclusionMode: ExclusionMode.Ignore

        readonly property int panelPadding: 10
        readonly property real panelHeight: notificationColumn.implicitHeight > 0
            ? notificationColumn.implicitHeight + panelPadding * 2 : 0
        // Same top-left corner treatment as Drawer/BatteryPanel: this stays
        // square (radius 0) and a same-colour Canvas carves the concave
        // curve next to it, so the panel reads as continuing the bar's
        // rounded corner inward instead of having its own convex corner.
        readonly property real cornerSize: PanelService.barVisible ? PanelService.shellRounding : 0

        // Bounding box for the whole row (corner notch + panel), not just
        // the panel rect -- keeps the layer surface height stable while
        // entries are removed instead of stretching the final entry frame.
        mask: Region { width: window.panelHeight > 0 ? window.width : 0; height: window.panelHeight }

        WlrLayershell.namespace: "quickshell:notifications"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            right: true
            bottom: true
        }

        // Flush against the bar's underside and the screen's right edge,
        // same as every other system panel (Drawer/BatteryPanel), instead
        // of floating with a gap on either side.
        margins.top: PanelService.barVisible ? PanelService.barHeight : 0

        Canvas {
            id: cornerCanvas
            width: window.cornerSize
            height: Math.min(width, window.panelHeight)

            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, width);
                context.fillStyle = Theme.base01;
                context.beginPath();
                context.moveTo(0, 0);
                context.lineTo(width, 0);
                context.lineTo(width, width);
                context.arc(0, width, width, 0, -Math.PI / 2, true);
                context.fill();
            }
        }

        // Shadow-only copy behind the visible panel. The MultiEffect shader
        // softens the *whole* layered texture including the source rect's
        // own edges (not just the cast shadow), which put a 1px translucent
        // fringe along the flush top edge even with clip: true. Keeping the
        // effect on an invisible twin behind the real fill means only the
        // shadow (which spills outside the rect on the right/bottom, where
        // it's supposed to) is soft -- the opaque fill on top stays crisp.
        Rectangle {
            x: panelBg.x
            width: panelBg.width
            height: panelBg.height
            color: Theme.base01
            radius: panelBg.radius
            topLeftRadius: 0
            topRightRadius: 0
            bottomRightRadius: 0
            layer.enabled: true
            layer.effect: ShellShadow {}
        }

        // One shared panel background behind the whole stack -- same fill
        // and corner radius as the rest of the system panels -- instead of
        // each notification being its own separately-rounded floating card.
        Rectangle {
            id: panelBg

            x: window.cornerSize
            width: window.width - window.cornerSize
            height: window.panelHeight
            color: Theme.base01
            radius: PanelService.shellRounding
            topLeftRadius: 0
            topRightRadius: 0
            // Right edge sits flush against the screen edge top to bottom,
            // so it stays a straight line -- only the left side (the one
            // that floats clear of the screen edge) keeps a rounded corner.
            bottomRightRadius: 0

            Column {
                id: notificationColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: window.panelPadding
                }
                spacing: 4

                Repeater {
                    model: server.trackedNotifications

                    Column {
                        id: rowWrapper
                        required property Notification modelData
                        required property int index
                        width: notificationColumn.width
                        spacing: 4

                        Separator { visible: rowWrapper.index > 0 }

                        NotificationCard { notification: rowWrapper.modelData }
                    }
                }
            }
        }
    }

    // Single transient notification row, one entry in the shared panel
    // above. Only ever instantiated by the Repeater above.
    component NotificationCard: Item {
        id: card

        required property Notification notification

        property bool closing: false
        readonly property int timeoutMs: {
            if (notification.expireTimeout === 0)
                return 0;
            if (notification.expireTimeout > 0)
                return Math.round(notification.expireTimeout);
            return notification.urgency === NotificationUrgency.Critical ? 10000 : 6000;
        }

        function normalizedIdentity(value: string): string {
            return String(value || "").toLowerCase()
                .replace(/\.desktop$/, "").replace(/[^a-z0-9]/g, "");
        }

        function focusOrigin(): bool {
            const candidates = [card.notification.desktopEntry, card.notification.appName]
                .map(value => card.normalizedIdentity(value)).filter(value => value.length > 0);

            for (const toplevel of Hyprland.toplevels.values) {
                const ipc = toplevel.lastIpcObject ?? {};
                const identities = [toplevel.wayland?.appId ?? "", ipc.class ?? "",
                    ipc.initialClass ?? ""].map(value => card.normalizedIdentity(value));

                for (const candidate of candidates) {
                    const match = identities.some(identity => identity === candidate
                        || (candidate.length >= 4 && identity.length >= 4
                            && (identity.includes(candidate) || candidate.includes(identity))));
                    if (match && toplevel.wayland) {
                        toplevel.wayland.activate();
                        return true;
                    }
                }
            }
            return false;
        }

        function defaultAction(): var {
            for (const action of notification.actions) {
                if (action.identifier === "default")
                    return action;
            }
            return null;
        }

        function activate(): void {
            const action = card.defaultAction();
            if (action)
                action.invoke();
            else
                card.focusOrigin();
            card.close(false);
        }

        function close(expired: bool): void {
            if (card.closing)
                return;
            card.closing = true;
            if (expired)
                notification.expire();
            else
                notification.dismiss();
        }

        width: notificationColumn.width
        implicitHeight: textContent.implicitHeight + 16
        height: implicitHeight

        Timer {
            interval: card.timeoutMs
            running: interval > 0 && !card.closing && !notificationMouse.containsMouse
            onTriggered: card.close(true)
        }

        // Plain hover highlight, same treatment as rows in the other
        // panels (e.g. network list entries), no per-card background.
        Rectangle {
            anchors.fill: parent
            radius: PanelService.shellRounding
            color: notificationMouse.containsMouse ? Utils.alpha(Theme.base05, 0.08) : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Column {
            id: textContent
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: 12
                rightMargin: 12
                topMargin: 8
            }
            spacing: 10

            Text {
                width: parent.width
                text: card.notification.summary
                visible: text !== ""
                color: Theme.base05
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                font.family: Theme.monospace
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: card.notification.body
                visible: text !== ""
                color: Theme.base05
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 4
                font.family: Theme.monospace
                font.pixelSize: 12
                lineHeight: 1.2
            }
        }

        MouseArea {
            id: notificationMouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    card.close(false);
                else
                    card.activate();
            }
        }
    }
}
