pragma Singleton

import QtQuick
import Quickshell

// Small stateless helpers shared across bar and panel components.
QtObject {
    // One shared, subtle readability increase for all shell text and font glyphs.
    readonly property int fontSizeAdjustment: 1

    // Shared scrim strength for overlays that dim the desktop directly with no wallpaper layer of their own drawn underneath.
    readonly property real scrimOpacity: 0.55

    function scaledFont(pixelSize: real): real {
        return pixelSize + fontSizeAdjustment;
    }

    // Subsequence match: every character of `token`, in order, somewhere in `haystack`.
    function fuzzyMatches(haystack: string, token: string): bool {
        let index = -1;
        for (const character of token) {
            index = haystack.indexOf(character, index + 1);
            if (index === -1)
                return false;
        }
        return true;
    }

    // Screen object for a Hyprland monitor name, falling back to the first screen.
    function screenForMonitor(name: string): var {
        for (const screen of Quickshell.screens) {
            if (String(screen.name) === name)
                return screen;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    // PwNodePeakMonitor peak -> 0..1 meter fill.
    function peakLevel(peak: real): real {
        return Math.max(0, Math.min(1, Math.pow(Math.max(0, Number(peak || 0)), 0.75)));
    }

    // Theme color with an overridden alpha, e.g. a faint hover fill derived from Theme.base05.
    function alpha(base: color, a: real): color {
        return Qt.rgba(base.r, base.g, base.b, a);
    }
}
