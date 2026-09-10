pragma Singleton

// Is a portal screencast running, and if so, of which output.
//
// "Running" comes from PipeWire: XDPH creates one xdph-streaming-* source per
// active capture, so the node list is the truth about whether anything is
// being shared right now.
//
// *Which* output is not exposed anywhere -- neither the portal nor hyprctl can
// be asked what a running cast is capturing. The one place the answer exists
// is the picker's own stdout ("[SELECTION]screen:DP-1"), which XDPH reads, so
// home/screen-share.nix wraps the picker binary and tees that line into the
// file watched below. Stale between casts, which is why outputName is gated
// on `active`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    // No PwObjectTracker here: AudioService already tracks every PipeWire node
    // (objects: root.nodes, unfiltered), which is what keeps .ready and
    // .properties populated below. Add one here if that ever narrows.
    readonly property var nodes: Pipewire.nodes
        ? Pipewire.nodes.values.filter(node => node && node.ready
            && (node.name.startsWith("xdph-streaming-")
                || String(node.properties["media.name"] || "")
                    .startsWith("xdph-streaming-"))) : []
    readonly property bool active: nodes.length > 0

    // Last picker choice, verbatim: "screen:DP-1", "region:DP-1@x,y,w,h" or
    // "window:0x…". Window shares name no output, so they leave this empty --
    // the indicator in the bar still shows, only the border is skipped.
    property string selection: ""
    readonly property string outputName: {
        if (!active)
            return "";
        // ponytail: last selection wins; two concurrent casts of different
        // outputs would only border the newer one. Track per-node if that
        // ever comes up (the portal would have to expose the mapping first).
        const match = /^(?:screen|region):([^@\s]+)/.exec(selection);
        return match ? match[1] : "";
    }

    FileView {
        path: `${Quickshell.env("XDG_RUNTIME_DIR")}/xdph-share-selection`
        watchChanges: true
        preload: true
        printErrors: false
        onLoaded: root.selection = text().trim().replace(/^\[SELECTION\]/, "")
        onFileChanged: reload()
    }
}
