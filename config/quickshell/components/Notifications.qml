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
    // Shared clock for the cards' relative "2m" timestamps.
    property double now: Date.now()

    Timer {
        interval: 30000
        repeat: true
        running: server.trackedNotifications.values.length > 0
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    function focusedMonitorName(): string {
        return Hyprland.focusedMonitor?.name ?? "";
    }

    function clearNotifications(): void {
        for (const notification of server.trackedNotifications.values)
            notification.dismiss();
    }

    Component.onCompleted: {
        if (DoNotDisturbService.active)
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
            if (DoNotDisturbService.active) {
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
        function onActiveChanged(): void {
            if (DoNotDisturbService.active)
                root.clearNotifications();
        }
    }

    PanelWindow {
        id: window

        screen: Utils.screenForMonitor(root.targetScreenName)
        visible: !DoNotDisturbService.active
            && server.trackedNotifications.values.length > 0
        color: "transparent"
        implicitWidth: 450
        implicitHeight: Math.max(1, window.panelHeight)
        exclusionMode: ExclusionMode.Ignore

        // Round up to the surface's integer pixel size so its lower edge is not
        // placed just outside the window and clipped.
        readonly property int panelHeight: notificationColumn.implicitHeight > 0
            ? Math.ceil(notificationColumn.implicitHeight) : 0
        // Bounding box for the whole row, not just the panel rect.
        mask: Region { width: window.panelHeight > 0 ? window.width : 0; height: window.height }

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

        // Each notification is its own card; the window itself stays transparent.
        Column {
            id: notificationColumn
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            spacing: 6

            Repeater {
                model: server.trackedNotifications

                NotificationCard {
                    required property Notification modelData
                    notification: modelData
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
            const candidates = (card.webApp
                ? [card.webApp.startupClass, card.webApp.id]
                : [card.notification.desktopEntry, card.notification.appName])
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

        readonly property bool critical: notification.urgency === NotificationUrgency.Critical
        readonly property double arrivedAt: Date.now()
        readonly property var extraActions: Array.from(notification.actions ?? [])
            .filter(action => action.identifier !== "default" && action.text !== "")
        // Fraction of the timeout still left; drives the countdown bar.
        property real remaining: 1

        // Browsers send web page notifications as themselves, naming the page's
        // origin in the body. Resolve that origin to the web app's desktop entry,
        // whose exec line opens the same host.
        readonly property bool fromBrowser: ["chromium", "chromiumbrowser", "firefox"]
            .includes(card.normalizedIdentity(notification.desktopEntry || notification.appName))
        readonly property var webApp: {
            if (!card.fromBrowser)
                return null;
            const bareHost = host => host.toLowerCase().replace(/^www\./, "");
            const hosts = (`${notification.summary} ${notification.body}`
                .match(/(?:[a-z0-9-]+\.)+[a-z]{2,}/gi) ?? []).map(bareHost);
            if (hosts.length === 0)
                return null;
            for (const entry of DesktopEntries.applications.values) {
                for (const arg of entry.command) {
                    const url = String(arg).match(/^(?:--app=)?https?:\/\/([^/?#:]+)/);
                    if (url && hosts.includes(bareHost(url[1])))
                        return entry;
                }
            }
            return null;
        }
        // Drop the leading origin line browsers prefix the body with (a link when
        // hyperlinks are supported); the header already names the web app.
        readonly property string body: card.fromBrowser
            ? String(notification.body || "")
                .replace(/^\s*(?:<a\b[^>]*>[^<]*<\/a>|[a-z0-9.-]+\.[a-z]{2,}(?::\d+)?)[ \t]*(?:\n+|$)/i, "")
            : notification.body
        readonly property string appName: card.webApp?.name
            ?? String(notification.appName || "Notification")

        readonly property string iconSource: {
            if (card.webApp?.icon)
                return Quickshell.iconPath(card.webApp.icon, true);
            // notify-send style icons arrive pre-resolved as `image` (image://icon/...).
            if (String(notification.image || "") !== "")
                return notification.image;
            let name = String(notification.appIcon || "");
            if (name === "" && notification.desktopEntry !== "")
                name = String(DesktopEntries.byId(notification.desktopEntry)?.icon ?? "");
            if (name === "" && notification.appName !== "")
                name = String(DesktopEntries.heuristicLookup(notification.appName)?.icon ?? "");
            if (name === "")
                return "";
            if (name.startsWith("/"))
                return "file://" + name;
            if (name.includes("://"))
                return name;
            return Quickshell.iconPath(name, true);
        }

        function relativeTime(): string {
            const seconds = Math.max(0, (root.now - card.arrivedAt) / 1000);
            if (seconds < 60) return "NOW";
            if (seconds < 3600) return `${Math.floor(seconds / 60)}M`;
            return `${Math.floor(seconds / 3600)}H`;
        }

        width: notificationColumn.width
        implicitHeight: content.implicitHeight + 28
        height: implicitHeight

        NumberAnimation {
            target: card
            property: "remaining"
            from: 1
            to: 0
            duration: card.timeoutMs
            running: card.timeoutMs > 0 && !card.closing
            paused: running && cardHover.hovered
            onFinished: card.close(true)
        }

        HoverHandler {
            id: cardHover
        }

        Rectangle {
            anchors.fill: parent
            color: cardHover.hovered ? Qt.tint(Theme.base01, Utils.alpha(Theme.base05, 0.04)) : Theme.base01

            Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    card.close(false);
                else
                    card.activate();
            }
        }

        Column {
            id: content
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                leftMargin: 16; rightMargin: 16; topMargin: 14
            }
            spacing: 10

            // App icon, app name, age and a close button.
            Item {
                width: parent.width
                height: 18

                Image {
                    id: appIcon
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 16
                    height: 16
                    source: card.iconSource
                    sourceSize.width: 32
                    sourceSize.height: 32
                    asynchronous: true
                    smooth: true
                    visible: status === Image.Ready
                }

                ShellText {
                    id: fallbackIcon
                    anchors.centerIn: appIcon
                    visible: !appIcon.visible
                    text: "󰂚"
                    color: Theme.textSecondary
                    size: 13
                }

                ShellText {
                    anchors {
                        left: appIcon.right; leftMargin: 10
                        right: age.left; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    text: card.appName.toUpperCase()
                    color: Theme.textSecondary
                    size: 11
                    font.letterSpacing: 1.2
                    elide: Text.ElideRight
                }

                ShellText {
                    id: age
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    // The close button takes this spot while the card is hovered.
                    opacity: cardHover.hovered ? 0 : 1
                    text: card.relativeTime()
                    color: Theme.textMuted
                    size: 10
                    font.letterSpacing: 1.2

                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                ShellText {
                    id: closeButton
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: "󰅖"
                    color: closeMouse.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    opacity: cardHover.hovered ? 1 : 0
                    size: 13

                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    MouseArea {
                        id: closeMouse
                        anchors { fill: parent; margins: -6 }
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.close(false)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4

                ShellText {
                    width: parent.width
                    text: card.notification.summary
                    visible: text !== ""
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    size: 13
                    font.bold: true
                }

                ShellText {
                    width: parent.width
                    text: card.body
                    visible: text !== ""
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 4
                    color: Theme.textSecondary
                    size: 12
                    lineHeight: 1.15
                }
            }

            // Sender-defined actions other than the click-to-activate default.
            Row {
                visible: card.extraActions.length > 0
                spacing: 6

                Repeater {
                    model: card.extraActions

                    Rectangle {
                        id: actionButton

                        required property var modelData

                        width: actionLabel.implicitWidth + 20
                        height: 26
                        radius: PanelService.rounding
                        color: actionMouse.containsMouse
                            ? Utils.alpha(Theme.base05, 0.14) : Utils.alpha(Theme.base05, 0.07)

                        ShellText {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: actionButton.modelData.text
                            size: 11
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                actionButton.modelData.invoke();
                                card.close(false);
                            }
                        }
                    }
                }
            }
        }

        // Countdown to auto-dismiss; pauses while hovered.
        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom }
            height: 2
            width: parent.width * card.remaining
            visible: card.timeoutMs > 0
            color: card.critical ? Theme.base08 : Utils.alpha(Theme.base05, 0.35)
        }
    }
}
