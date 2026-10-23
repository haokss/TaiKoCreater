import QtQuick 2.15
import QtQuick.Controls 2.15

// 波形可视化面板 — 静态波形 + 播放头 + 滚轮缩放 + 水平拖动
Rectangle {
    id: root
    property int myIdx: 4
    property Item dockArea: null
    property real zoomLevel: 1.0
    property real scrollX: 0

    signal dragReleased()
    signal zoomRequested(real delta, real mouseXRatio)
    signal panRequested(real dx)

    width: 1200; height: 150; radius: 8
    color: "#FFFFFF"
    border.color: dragArea.drag.active ? "#2196F3" : "#DDD"
    border.width: dragArea.drag.active ? 2 : 1
    z: dragArea.drag.active ? 10 : 1
    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    function progressRatio() {
        if (!audioPlayer || audioPlayer.duration <= 0) return 0
        return Math.min(1.0, audioPlayer.position / audioPlayer.duration)
    }

    // 波形绘制区域
    Item {
        id: waveArea
        anchors.fill: parent
        anchors.topMargin: 34; anchors.bottomMargin: 4; anchors.leftMargin: 8; anchors.rightMargin: 8
        clip: true

        // 缩放容器 — 水平偏移
        Item {
            id: waveInner
            width: parent.width * zoomLevel
            height: parent.height
            x: -scrollX

            Canvas {
                id: waveCanvas
                anchors.fill: parent
                renderStrategy: Canvas.Immediate

                property var data: []
                property int pointCount: 0

                Connections {
                    target: audioPlayer
                    onWaveformDataChanged: {
                        waveCanvas.data = audioPlayer.waveformData
                        waveCanvas.pointCount = waveCanvas.data ? waveCanvas.data.length : 0
                        waveCanvas.requestPaint()
                    }
                }

                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    var w = width, h = height
                    ctx.clearRect(0, 0, w, h)

                    if (pointCount <= 0) {
                        ctx.fillStyle = "#AAA"
                        ctx.font = "11px sans-serif"
                        ctx.textAlign = "center"
                        ctx.fillText(w > 100 ? "无波形数据" : "", w / 2, h / 2 + 5)
                        return
                    }

                    var barWidth = w / pointCount
                    var centerY = h / 2

                    ctx.fillStyle = "#AAAAAA"
                    for (var i = 0; i < pointCount; i++) {
                        var amp = data[i] || 0
                        var barH = Math.max(1, amp * centerY * 0.9)
                        if (barWidth >= 1) {
                            ctx.fillRect(i * barWidth + 1, centerY - barH, Math.max(1, barWidth - 2), barH * 2)
                        } else {
                            ctx.fillRect(i * barWidth, centerY - barH, 1, barH * 2)
                        }
                    }
                }
            }

            // 已播放覆盖层
            Rectangle {
                id: playedOverlay
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.progressRatio()
                color: "#80E60012"
                visible: audioPlayer && audioPlayer.duration > 0
            }

            // 播放头竖线
            Rectangle {
                id: playhead
                x: parent.width * root.progressRatio() - 1
                y: 0
                width: 2
                height: parent.height
                color: "#E60012"
                visible: audioPlayer && audioPlayer.duration > 0
            }
        }

        // 点击跳转 / 拖动平移 / 滚轮缩放
        MouseArea {
            anchors.fill: parent
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real pressX: 0
            property real pressScrollX: 0
            property bool isDragging: false

            onPressed: function(mouse) {
                pressX = mouse.x
                pressScrollX = root.scrollX
                isDragging = false
            }
            onPositionChanged: function(mouse) {
                var dx = mouse.x - pressX
                if (Math.abs(dx) > 3) isDragging = true
                if (isDragging)
                    root.panRequested(pressScrollX + pressX - mouse.x - scrollX)
            }
            onReleased: function(mouse) {
                if (!isDragging) {
                    if (!audioPlayer || audioPlayer.duration <= 0) return
                    var ratio = (mouse.x + root.scrollX) / waveInner.width
                    var targetMs = Math.max(0, Math.min(audioPlayer.duration, ratio * audioPlayer.duration))
                    audioPlayer.setPosition(targetMs)
                }
                isDragging = false
            }
            acceptedButtons: Qt.LeftButton
            onWheel: function(wheel) {
                var delta = wheel.angleDelta.y > 0 ? 0.15 : -0.15
                var mouseXRatio = wheel.x / parent.width
                root.zoomRequested(delta, mouseXRatio)
                wheel.accepted = true
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 30
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.minimumX: 0; drag.minimumY: 0
        drag.maximumX: Qt.binding(function() { return dockArea ? Math.max(0, dockArea.width - root.width) : 0 })
        drag.maximumY: Qt.binding(function() { return dockArea ? Math.max(0, dockArea.height - root.height) : 0 })
        onReleased: root.dragReleased()
    }
}