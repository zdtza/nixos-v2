pragma Singleton

// Bar placement and layout. Edit this file to move the bar or rearrange it.
//
// Sections run along the bar: `start` is the left end, `center` the middle and
// `end` the right end (top, middle and bottom should the bar ever sit on a
// side edge). Items show in the order listed; leave an item out to hide it.
// A panel opens at the start, centre or end of the screen to match the
// section of the item it belongs to.
//
// Items:
//   workspaces    workspace switcher and taskbar
//   quickToggles  caffeine, do-not-disturb and night light toggles
//   clock         clock (click: clock and calendar panel)
//   tray          system tray and minimised windows
//   bluetooth, audio, battery, network
import QtQuick

QtObject {
    // "top" or "bottom".
    property string position: "top"

    property var start: ["workspaces"]
    property var center: ["quickToggles", "clock"]
    property var end: ["tray", "bluetooth", "audio", "battery", "network"]

    // The centre item that stays fixed in the middle of the bar; items before it
    // grow towards the start and items after it towards the end. Falls back to
    // the middle of `center` when it is not listed there.
    property string centerPivot: "clock"

    readonly property var sections: ({ start, center, end })

    // Section ("start", "center" or "end") holding `item`, or "" when not shown.
    function sectionOf(item: string): string {
        for (const section of ["start", "center", "end"])
            if (sections[section].includes(item))
                return section;
        return "";
    }

    // Where a panel opens: the section of the first of its bar items that is shown.
    function alignmentFor(items: var, fallback: string): string {
        for (const item of items ?? []) {
            const section = sectionOf(item);
            if (section !== "")
                return section;
        }
        return fallback;
    }
}
