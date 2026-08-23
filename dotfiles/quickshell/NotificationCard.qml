pragma ComponentBehavior: Bound

// Single transient notification styled after the shell's square panel cards.
import QtQuick
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Stylix

Item {
    id: root

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
        if (notification.urgency === NotificationUrgency.Low)
            return Theme.muted;
        return Theme.accent;
    }

    function normalizedIdentity(value: string): string {
        return String(value || "").toLowerCase()
            .replace(/\.desktop$/, "").replace(/[^a-z0-9]/g, "");
    }

    function focusOrigin(): bool {
        const candidates = [notification.desktopEntry, notification.appName]
            .map(value => normalizedIdentity(value)).filter(value => value.length > 0);

        for (const toplevel of Hyprland.toplevels.values) {
            const ipc = toplevel.lastIpcObject ?? {};
            const identities = [toplevel.wayland?.appId ?? "", ipc.class ?? "",
                ipc.initialClass ?? ""].map(value => normalizedIdentity(value));

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
        const action = defaultAction();
        if (action)
            action.invoke();
        else
            focusOrigin();
        close(false);
    }

    function close(expired: bool): void {
        if (closing)
            return;
        closing = true;
        if (expired)
            notification.expire();
        else
            notification.dismiss();
    }

    width: 420
    implicitHeight: Math.max(64, textContent.implicitHeight + 24)
    height: implicitHeight

    Timer {
        interval: root.timeoutMs
        running: interval > 0 && !root.closing && !notificationMouse.containsMouse
        onTriggered: root.close(true)
    }

    Rectangle {
        anchors.fill: parent
        color: notificationMouse.containsMouse ? Theme.dark_background : Theme.background

        Rectangle {
            id: urgencyBar
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: 4
            color: root.urgencyColor()
        }

        Rectangle {
            anchors {
                left: urgencyBar.right
                right: parent.right
                top: parent.top
            }
            height: 2
            color: Theme.border
        }

        Rectangle {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            width: 2
            color: Theme.border
        }

        Rectangle {
            anchors {
                left: urgencyBar.right
                right: parent.right
                bottom: parent.bottom
            }
            height: 2
            color: Theme.border
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
                text: root.notification.summary
                visible: text !== ""
                color: Theme.foreground
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
                font.family: Theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: root.notification.body
                visible: text !== ""
                color: Theme.muted
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 4
                font.family: Theme.fontFamily
                font.pixelSize: 12
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
                root.close(false);
            else
                root.activate();
        }
    }
}
