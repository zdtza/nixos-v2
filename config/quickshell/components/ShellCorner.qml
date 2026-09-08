import QtQuick
import "../services"

// Concave notch that continues the bar's rounded corner inward, so a panel
// hanging off the bar's underside reads as carved out of it rather than as
// its own floating card with convex corners of its own.
//
// Draws the left-hand notch by default; `mirrored` draws the right-hand one.
// Callers set `width` to the corner size and clamp `height` to however much
// of the surface is currently revealed.
Canvas {
    id: root

    property bool mirrored: false

    onPaint: {
        const context = getContext("2d");
        context.clearRect(0, 0, width, width);
        context.fillStyle = Theme.base01;
        context.beginPath();
        context.moveTo(0, 0);
        context.lineTo(width, 0);
        if (root.mirrored) {
            context.arc(width, width, width, -Math.PI / 2, -Math.PI, true);
            context.lineTo(0, 0);
        } else {
            context.lineTo(width, width);
            context.arc(0, width, width, 0, -Math.PI / 2, true);
        }
        context.fill();
    }
}
