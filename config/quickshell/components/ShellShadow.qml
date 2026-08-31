import QtQuick.Effects

// Matches Hyprland's 30px, 0x33000000 window shadow with a 4px drop.
MultiEffect {
    shadowEnabled: true
    shadowBlur: 1
    blurMax: 32
    shadowColor: "#33000000"
    shadowVerticalOffset: 4
}
