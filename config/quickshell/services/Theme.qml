pragma Singleton

// Colors/fonts/wallpaper picked in themes/<theme>/default.nix. Loaded from a plain JSON
// file (home/quickshell.nix rewrites it *in place* on every `sw`, same inode,
// no symlink swap -- see that file for why) instead of a generated QML module
// imported via QML2_IMPORT_PATH: a swapped Nix store path was invisible to any
// file watcher, so quickshell never picked up a new theme without a full
// process restart (which also re-triggered the lock screen's autolock).
// watchChanges below is the same FileView idiom BatteryService.qml already
// uses to react to files that change outside of quickshell's own reload.
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property color base00: "#1a1b26"
    property color base01: "#13141c"
    property color base02: "#292e42"
    property color base03: "#414868"
    property color base04: "#565f89"
    property color base05: "#a9b1d6"
    property color base06: "#b4bee6"
    property color base07: "#c0caf5"
    property color base08: "#f7768e"
    property color base09: "#eb927b"
    property color base0A: "#e0af68"
    property color base0B: "#9ece6a"
    property color base0C: "#4dbfd0"
    property color base0D: "#7aa2f7"
    property color base0E: "#ad8ee6"
    property color base0F: "#75493d"
    property url wallpaper: ""
    property string monospace: "monospace"
    property int fontSize: 13

    function apply(data: var): void {
        base00 = data.base00;
        base01 = data.base01;
        base02 = data.base02;
        base03 = data.base03;
        base04 = data.base04;
        base05 = data.base05;
        base06 = data.base06;
        base07 = data.base07;
        base08 = data.base08;
        base09 = data.base09;
        base0A = data.base0A;
        base0B = data.base0B;
        base0C = data.base0C;
        base0D = data.base0D;
        base0E = data.base0E;
        base0F = data.base0F;
        wallpaper = "file://" + data.wallpaper;
        monospace = data.monospace;
    }

    FileView {
        path: `${Quickshell.env("HOME")}/.cache/quickshell/theme.json`
        watchChanges: true
        preload: true
        printErrors: false
        onLoaded: root.apply(JSON.parse(text()))
        onFileChanged: reload()
    }
}
