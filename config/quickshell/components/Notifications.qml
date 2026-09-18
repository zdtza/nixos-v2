pragma ComponentBehavior: Bound

// Freedesktop notification daemon and top-right notification stack.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import "../services"
import ".."

Scope {
    id: root

    // Only the monitor *name* is cached, never a screen object.
    property string targetScreenName: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

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
        // Senders (Teams in particular) check this capability before deciding how to present a link.
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

        screen: Utils.screenForMonitor(root.targetScreenName)
        visible: !DoNotDisturbService.enabled
            && server.trackedNotifications.values.length > 0
        color: "transparent"
        implicitWidth: 450
        exclusionMode: ExclusionMode.Ignore

        readonly property int panelPadding: 8
        readonly property int panelTopPadding: 0
        readonly property real panelHeight: notificationColumn.implicitHeight > 0
            ? notificationColumn.implicitHeight + panelTopPadding + panelPadding : 0
        // Same top-left corner treatment as Drawer/BatteryPanel.
        readonly property real cornerSize: PanelService.barVisible ? PanelService.shellRounding : 0

        // Bounding box for the whole row, not just the panel rect.
        mask: Region { width: window.panelHeight > 0 ? window.width : 0; height: window.panelHeight }

        WlrLayershell.namespace: "quickshell:notifications"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            right: true
            bottom: true
        }

        // Align with the bar bottom and screen right edge.
        margins.top: PanelService.barVisible ? PanelService.barHeight : 0

        ShellCorner {
            width: window.cornerSize
            height: Math.min(width, window.panelHeight)
        }

        // One shared panel background behind the whole stack.
        Rectangle {
            id: panelBg

            x: window.cornerSize
            width: window.width - window.cornerSize
            height: window.panelHeight
            color: Theme.base01
            radius: PanelService.shellRounding
            topLeftRadius: 0
            topRightRadius: 0
            // Right edge sits flush against the screen edge top to bottom, so it stays a straight line -- only the left side keeps a rounded corner.
            bottomRightRadius: 0

            Column {
                id: notificationColumn
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: window.panelPadding
                    topMargin: window.panelTopPadding
                }
                spacing: 2

                Repeater {
                    model: server.trackedNotifications

                    Column {
                        id: rowWrapper
                        required property Notification modelData
                        required property int index
                        width: notificationColumn.width
                        spacing: 2

                        Separator { visible: rowWrapper.index > 0 }

                        NotificationCard { notification: rowWrapper.modelData }
                    }
                }
            }
        }
    }

    // Single transient notification row, one entry in the shared panel above.
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
        implicitHeight: textContent.implicitHeight + 12
        height: implicitHeight

        Timer {
            interval: card.timeoutMs
            running: interval > 0 && !card.closing && !notificationMouse.containsMouse
            onTriggered: card.close(true)
        }

        // Plain hover highlight, same treatment as rows in the other panels (e.g. network list entries), no per-card background.
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
                leftMargin: 10
                rightMargin: 10
                topMargin: 6
            }
            spacing: 6

            ShellText {
                width: parent.width
                text: card.notification.summary
                visible: text !== ""
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            ShellText {
                width: parent.width
                text: card.notification.body
                visible: text !== ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 4
                color: Theme.base04
                font.pixelSize: 12
                lineHeight: 1.1
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
