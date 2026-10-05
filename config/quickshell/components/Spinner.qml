import QtQuick
import QtQuick.Shapes
import "../services"

// A 2px ring with an arc missing (360 - sweepAngle), turning continuously while visible.
Shape {
    id: root

    property real size: 14
    property color color: Theme.textPrimary

    width: size
    height: size
    preferredRendererType: Shape.CurveRenderer
    layer.enabled: true
    layer.samples: 4

    ShapePath {
        strokeColor: root.color
        strokeWidth: 2
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap

        PathAngleArc {
            centerX: root.size / 2
            centerY: root.size / 2
            radiusX: root.size / 2 - 1
            radiusY: root.size / 2 - 1
            startAngle: 0
            sweepAngle: 220
        }
    }

    RotationAnimator on rotation {
        running: root.visible
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
    }
}
