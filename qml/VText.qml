import QtQuick
import QtQuick.Effects

Text {
    property int weight: 400
    property bool useShadow: false
    font.family: {
        if(weight < 500) return Fonts.hankenRegular
        else if(weight < 550) return Fonts.hankenMedium
        else if(weight < 600) return Fonts.hankenSemiBold
        else if(weight < 1000) return Fonts.hankenBold
    }
    font.weight: weight

    layer.enabled: useShadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#30ffffff"
            shadowBlur: 0.6
            shadowHorizontalOffset: 1
            shadowVerticalOffset: 1
        }
}
