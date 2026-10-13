import QtQuick
import QtQuick.Effects
import "../../services"

// Drop shadow behind a floating shell card. Give it the card's geometry and
// stack it below the card.
RectangularShadow {
    color: Theme.shadowColor
    blur: Theme.shadowBlur
    offset.y: Theme.shadowOffsetY
}
