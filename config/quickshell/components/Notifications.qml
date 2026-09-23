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
    // Notification app names are often generic (e.g. `notify-send`). Capture
    // the focused client at delivery time as the reliable click target.
    property var notificationOrigins: ({})

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
            const source = Hyprland.activeToplevel;
            if (source?.address) {
                // QML's JS engine does not support object spread. Copy the map
                // explicitly so assigning it still emits a property change.
                const origins = {};
                for (const key in root.notificationOrigins)
                    origins[key] = root.notificationOrigins[key];
                origins[String(notification.id)] = {
                    address: String(source.address),
                    workspaceId: Number(source.workspace?.id ?? 0)
                };
                root.notificationOrigins = origins;
            }
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
        implicitHeight: Math.max(1, window.panelHeight)
        exclusionMode: ExclusionMode.Ignore

        readonly property int panelPadding: 8
        readonly property int panelTopPadding: 8
        readonly property real panelHeight: notificationColumn.implicitHeight > 0
            ? notificationColumn.implicitHeight + panelTopPadding + panelPadding : 0
        // Bounding box for the whole row, not just the panel rect.
        mask: Region { width: window.panelHeight > 0 ? window.width : 0; height: window.panelHeight }

        WlrLayershell.namespace: "quickshell:notifications"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            right: true
            top: PanelService.barAtTop
            bottom: !PanelService.barAtTop
        }

        // Float beside the bar and clear of the right screen edge.
        margins.top: PanelService.barAtTop
            ? PanelService.panelBarInset + PanelService.panelGap : 0
        margins.bottom: PanelService.barAtTop
            ? 0 : PanelService.panelBarInset + PanelService.panelGap
        margins.right: PanelService.panelGap + PanelService.gapRightOffset

        // One shared panel background behind the whole stack.
        Rectangle {
            id: panelBg

            width: window.width
            height: window.panelHeight
            color: Theme.base01
            radius: 0
            border.width: PanelService.chromeBorderWidth
            border.color: PanelService.chromeBorderColor

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

        function focusToplevel(toplevel: var): bool {
            let address = String(toplevel?.address ?? "");
            if (address === "")
                return false;
            if (!address.startsWith("0x"))
                address = `0x${address}`;

            // This is the Lua-dispatch form used by the rest of the Hyprland
            // configuration. Focusing by address also selects the window's
            // workspace, avoiding a race between separate workspace/window
            // dispatches. Hyprland requires the 0x address prefix.
            Quickshell.execDetached(["hyprctl", "dispatch",
                `hl.dsp.focus({ window = 'address:${address}' })`]);
            return true;
        }

        function focusOrigin(): bool {
            // Prefer sender metadata when it identifies a real application.
            // This handles notifications emitted by background applications.
            const candidates = [card.notification.desktopEntry, card.notification.appName]
                .map(value => card.normalizedIdentity(value)).filter(value => value.length > 0);
            for (const toplevel of Hyprland.toplevels.values) {
                const ipc = toplevel.lastIpcObject ?? {};
                const identities = [toplevel.wayland?.appId ?? "", ipc.class ?? "",
                    ipc.initialClass ?? ""].map(value => card.normalizedIdentity(value));
                if (candidates.some(candidate => identities.some(identity => identity === candidate
                    || (candidate.length >= 4 && identity.length >= 4
                        && (identity.includes(candidate) || candidate.includes(identity))))))
                    return focusToplevel(toplevel);
            }

            // Utilities such as notify-send identify themselves rather than
            // the terminal that invoked them. For those, use the exact window
            // which was focused when the notification arrived.
            const captured = root.notificationOrigins[String(card.notification.id)];
            if (captured?.address) {
                const wanted = String(captured.address).replace(/^0x/, "");
                const source = Hyprland.toplevels.values.find(toplevel =>
                    String(toplevel.address ?? "").replace(/^0x/, "") === wanted);
                if (source)
                    return focusToplevel(source);
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
            const actions = notification.actions ?? [];
            // A notification with no actions behaves like a window switcher.
            // When actions are supplied, only its advertised default action is
            // invoked; never substitute a focus action for a sender action.
            if (actions.length === 0)
                card.focusOrigin();
            else {
                const action = card.defaultAction();
                if (action)
                    action.invoke();
            }
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
            radius: 0
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
                opacity: 0.7
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
