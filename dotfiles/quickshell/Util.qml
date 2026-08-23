pragma Singleton

import QtQuick

// Small stateless helpers shared across bar and panel components.
QtObject {
    // Theme color with an overridden alpha, e.g. a faint hover fill derived
    // from Theme.foreground.
    function alpha(base: color, a: real): color {
        return Qt.rgba(base.r, base.g, base.b, a);
    }
}
