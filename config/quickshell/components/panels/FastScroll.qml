// Consistent high-speed wheel and touchpad scrolling for shell lists.
import QtQuick

WheelHandler {
    id: root

    required property var view
    property real multiplier: 1.5

    target: null
    blocking: true
    acceptedDevices: PointerDevice.AllDevices

    onWheel: event => {
        let delta = Number(event.pixelDelta.y);
        if (delta === 0)
            delta = Number(event.angleDelta.y) / 120 * 100;
        if (event.inverted)
            delta = -delta;

        const minimum = Number(root.view.originY ?? 0);
        const maximum = Math.max(minimum,
            minimum + Number(root.view.contentHeight) - Number(root.view.height));
        root.view.contentY = Math.max(minimum, Math.min(maximum,
            Number(root.view.contentY) - delta * root.multiplier));
        event.accepted = true;
    }
}
