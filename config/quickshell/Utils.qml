pragma Singleton

import QtQuick

// Small stateless helpers shared across bar and panel components.
QtObject {
    // One shared, subtle readability increase for all shell text and font
    // glyphs. Keeps component proportions intact while allowing one-point
    // global adjustment.
    readonly property int fontSizeAdjustment: 1

    function scaledFont(pixelSize: real): real {
        return pixelSize + fontSizeAdjustment;
    }

    // Theme color with an overridden alpha, e.g. a faint hover fill derived
    // from Theme.base05.
    function alpha(base: color, a: real): color {
        return Qt.rgba(base.r, base.g, base.b, a);
    }
}
