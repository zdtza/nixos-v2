pragma ComponentBehavior: Bound

// Freedesktop notification daemon and top-right notification stack.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import Stylix

Scope {
    id: root

    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    function focusedScreen(): var {
        const monitorName = Hyprland.focusedMonitor?.name ?? "";
        for (const screen of Quickshell.screens) {
            if (screen.name === monitorName)
                return screen;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function clearNotifications(): void {
        for (const notification of server.trackedNotifications.values)
            notification.dismiss();
    }

    Component.onCompleted: {
        if (ServiceDoNotDisturb.enabled)
            Qt.callLater(root.clearNotifications);
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: false
        inlineReplySupported: false

        onNotification: notification => {
            if (ServiceDoNotDisturb.enabled) {
                notification.dismiss();
                return;
            }
            root.targetScreen = root.focusedScreen();
            notification.tracked = true;
        }
    }

    Connections {
        target: ServiceDoNotDisturb
        function onEnabledChanged(): void {
            if (ServiceDoNotDisturb.enabled)
                root.clearNotifications();
        }
    }

    PanelWindow {
        id: window

        screen: root.targetScreen
        visible: !ServiceDoNotDisturb.enabled
            && server.trackedNotifications.values.length > 0
        color: "transparent"
        implicitWidth: 450
        exclusionMode: ExclusionMode.Ignore

        // Keep layer surface height stable while cards are removed. Resizing
        // layer surface during model destruction stretches final card frame.
        mask: Region { item: notificationColumn }

        WlrLayershell.namespace: "quickshell:notifications"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            right: true
            bottom: true
        }

        margins {
            top: (ServicePanel.barHeight + ServicePanel.barIconHeight) / 2
                + ServicePanel.barGap + ServicePanel.gapTopOffset
            right: ServicePanel.barGap + ServicePanel.gapRightOffset
        }

        Column {
            id: notificationColumn

            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications

                NotificationCard {
                    required property Notification modelData
                    notification: modelData
                }
            }
        }
    }

    // Single transient notification styled after the shell's square panel
    // cards. Only ever instantiated by the Repeater above.
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

        function urgencyColor(): color {
            if (notification.urgency === NotificationUrgency.Critical)
                return Theme.urgent;
            else
                return Theme.muted;
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

        width: 450
        implicitHeight: textContent.implicitHeight + 22
        height: implicitHeight

        Timer {
            interval: card.timeoutMs
            running: interval > 0 && !card.closing && !notificationMouse.containsMouse
            onTriggered: card.close(true)
        }

        // Accent bar is this full-card rounded rect showing through down
        // the left edge; the actual background is a second rounded rect of
        // the same radius layered on top, inset 4px from the left. Sharing
        // one radius lets their corners nest without computing per-corner
        // insets, and both are solid fills (no Rectangle.border), which is
        // what actually caused the old top/right/bottom strips to visibly
        // smear for a frame when the layer-surface mask resizes on close.
        Rectangle {
            id: accentBase
            anchors.fill: parent
            radius: ServicePanel.rounding
            color: card.urgencyColor()

            Rectangle {
                anchors {
                    fill: parent
                    leftMargin: 4
                }
                radius: ServicePanel.rounding
                color: notificationMouse.containsMouse ? Theme.background : Theme.dark_background
            }

            Column {
                id: textContent
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: 24
                    rightMargin: 20
                    topMargin: 14
                }
                spacing: 10

                Text {
                    width: parent.width
                    text: card.notification.summary
                    visible: text !== ""
                    color: Theme.foreground
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    font.family: Theme.fontFamily
                    font.pixelSize: Util.scaledFont(14)
                    font.weight: Font.Bold
                }

                Text {
                    width: parent.width
                    text: card.notification.body
                    visible: text !== ""
                    color: Theme.muted
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 4
                    font.family: Theme.fontFamily
                    font.pixelSize: Util.scaledFont(12)
                    lineHeight: 1.35
                }
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
