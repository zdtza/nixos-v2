import QtQuick

// Vertical list viewport: clipped, only draggable when it overflows, and
// scrolled with the shell's fast wheel handling.
Flickable {
    id: root

    clip: true
    interactive: contentHeight > height
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    FastScroll { view: root }
}
