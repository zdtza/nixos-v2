pragma ComponentBehavior: Bound

// Freedesktop notification daemon and top-right notification stack.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland

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
        if (DoNotDisturbService.enabled)
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
            if (DoNotDisturbService.enabled) {
                notification.dismiss();
                return;
            }
            root.targetScreen = root.focusedScreen();
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

        screen: root.targetScreen
        visible: !DoNotDisturbService.enabled
            && server.trackedNotifications.values.length > 0
        color: "transparent"
        implicitWidth: 420
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
            top: 29 + PanelService.barGap
            right: 7
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
}
