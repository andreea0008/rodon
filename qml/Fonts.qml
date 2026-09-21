pragma Singleton
import QtQuick

QtObject {
    property string hankenRegular: hankenRegularFontLoader.name
    property FontLoader hankenRegularFontLoader: FontLoader {
        source: "qrc:/qt/qml/SVPN/ui/font/space_grotesk/SpaceGrotesk-Regular.ttf"
    }

    property string hankenMedium: hankenMediumFontLoader.name
    property FontLoader hankenMediumFontLoader: FontLoader {
        source: "qrc:/qt/qml/SVPN/ui/font/space_grotesk/SpaceGrotesk-Medium.ttf"
    }

    property string hankenSemiBold: hankenSemiBoldFontLoader.name
    property FontLoader hankenSemiBoldFontLoader: FontLoader {
        source: "qrc:/qt/qml/SVPN/ui/font/space_grotesk/SpaceGrotesk-SemiBold.ttf"
    }

    property string hankenBold: hankenBoldFontLoader.name
    property FontLoader hankenBoldFontLoader: FontLoader {
        source: "qrc:/qt/qml/SVPN/ui/font/space_grotesk/SpaceGrotesk-Bold.ttf"
    }
}
