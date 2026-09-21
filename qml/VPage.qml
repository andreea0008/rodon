import QtQuick

Item {
    width: parent.width
    height: parent.height
    Image {
        anchors.fill: parent
        source: "qrc:/qt/qml/SVPN/abstract-gradient-neon-lights.jpg"
        antialiasing: true
        smooth: true
    }
    
    Canvas {
        id: mesh
        anchors.fill: parent
        visible: true
        opacity: 0.2
        onPaint: {
            var ctx = getContext("2d");
            var w = parent.width / 12
            var innerw = w/3
            ctx.clearRect(0, 0, width, height);
            
            ctx.strokeStyle = "#5063397E";
            ctx.lineWidth = 1;
            
            for (var x = 0; x <= width; x += innerw) {
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
                ctx.stroke();
            }
            
            for (var y = 0; y <= height; y += innerw) {
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }
            
            ctx.strokeStyle = "#8063397E";
            ctx.lineWidth = 1;
            
            for ( x = 0; x <= width; x += w) {
                ctx.beginPath();
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
                ctx.stroke();
            }
            
            for (var y = 0; y <= height; y += w) {
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }
        }
        
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }
    
}
