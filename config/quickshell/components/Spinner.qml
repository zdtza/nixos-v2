import QtQuick
import QtQuick.Shapes
import "../services"

// A 2px ring with an arc missing (360 - sweepAngle), turning continuously while visible.
Shape {
    id: root

    property real size: 14
    property color color: Theme.textPrimary
    // Rotation of the arc. Spinners that should turn in step (e.g. every launch
    // indicator) bind this to a shared angle and set selfDriven to false.
    property real angle: 0
    property bool selfDriven: true

    width: size
    height: size
    // CurveRenderer antialiases analytically at native resolution; spinning the arc itself
    // (not the item) keeps it re-rendered every frame instead of resampling a rotated texture.
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: root.color
        strokeWidth: 2
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap

        PathAngleArc {
            id: arc
            centerX: root.size / 2
            centerY: root.size / 2
            radiusX: root.size / 2 - 1
            radiusY: root.size / 2 - 1
            startAngle: root.angle
            sweepAngle: 220
        }
    }

    NumberAnimation {
        target: root
        property: "angle"
        running: root.visible && root.selfDriven
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
    }
}
