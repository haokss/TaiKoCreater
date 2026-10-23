import QtQuick 2.15
import QtQuick.Controls 2.15

// 时间轴面板 — 播放头跟随 audioPlayer.position，支持滚轮缩放
Rectangle {
    id: root
    property int myIdx: 3
    property Item dockArea: null
    property real zoomLevel: 1.0
    property real scrollX: 0        // 由 FlexLayoutPage 传入

    signal dragReleased()
    signal zoomRequested(real delta, real mouseXRatio)
    signal panRequested(real dx)

    width: 1200; height: 70; radius: 8
    color: "#162132"
    border.color: dragArea.drag.active ? "#8B5CF6" : "#273247"
    border.width: dragArea.drag.active ? 2 : 1
    z: dragArea.drag.active ? 10 : 1
    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    function formatTime(ms) {
        if (!ms || ms <= 0) return "0:00"
        var totalSec = Math.floor(ms / 1000)
        var min = Math.floor(totalSec / 60)
        var sec = totalSec % 60
        return min + ":" + (sec < 10 ? "0" : "") + sec
    }

    function progressRatio() {
        if (!audioPlayer || audioPlayer.duration <= 0) return 0
        return Math.min(1.0, audioPlayer.position / audioPlayer.duration)
    }

    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 30; radius: 8; color: "#111827"
        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 8; color: "#8B5CF6" }
        Row {
            anchors.centerIn: parent
            spacing: 12
            Text { text: "时间轴"; color: "#C9D2E3"; font.bold: true; font.pointSize: 11 }
            Text {
                text: root.formatTime(audioPlayer ? audioPlayer.position : 0)
                   + " / " + root.formatTime(audioPlayer ? audioPlayer.duration : 0)
                color: "#FFD54F"; font.pointSize: 9
            }
            Text {
                text: Math.round(zoomLevel * 100) + "%"
                color: "#FFD54F"; font.pointSize: 9
            }
        }
    }

    // 时间轴内容区（可缩放）
    Item {
        id: timelineContent
        anchors.fill: parent
        anchors.topMargin: 32; anchors.bottomMargin: 4; anchors.leftMargin: 8; anchors.rightMargin: 8
        clip: true

        // 缩放容器
        Item {
            id: timelineInner
            width: parent.width * zoomLevel
            height: parent.height
            x: -scrollX
            transformOrigin: Item.TopLeft

            // 刻度线
            Row {
                anchors.fill: parent
                Repeater {
                    model: 29
                    Rectangle {
                        width: parent ? parent.width / 29 : 20; height: parent.height
                        color: "transparent"
                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 1; height: 10
                            color: index % 4 === 0 ? "#5B657A" : "#273247"
                        }
                        Text {
                            anchors.top: parent.top; anchors.topMargin: 12
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: {
                                if (index % 4 !== 0) return ""
                                var s = index * 5
                                var m = Math.floor(s / 60)
                                var sec = s % 60
                                return m + ":" + (sec < 10 ? "0" : "") + sec
                            }
                            font.pointSize: 7; color: "#5B657A"
                        }
                    }
                }
            }

            // 假音符标记
            Repeater {
                model: [
                    { beat: 0, type: "don" },
                    { beat: 4, type: "ka" },
                    { beat: 8, type: "don" },
                    { beat: 14, type: "don" },
                    { beat: 18, type: "ka" },
                    { beat: 22, type: "don" },
                    { beat: 26, type: "ka" }
                ]
                Rectangle {
                    x: parent.width * (modelData.beat / 28)
                    y: parent.height * 0.5 - 8
                    width: 14; height: 14
                    radius: modelData.type === "don" ? 7 : 3
                    color: modelData.type === "don" ? "#E60012" : "#4DA3FF"
                    Text {
                        anchors.centerIn: parent
                        text: modelData.type === "don" ? "ド" : "カ"
                        font.pointSize: 6; color: "white"
                    }
                }
            }

            // 播放头
            Rectangle {
                id: playhead
                x: parent.width * root.progressRatio() - 1; y: 0
                width: 2; height: parent.height
                color: "#E60012"
                visible: audioPlayer && audioPlayer.duration > 0
                Behavior on x { SmoothedAnimation { velocity: 80 } }
            }
        }

        // 点击跳转 + 拖动平移 + 滚轮缩放
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
                if (Math.abs(dx) > 3)
                    isDragging = true
                if (isDragging)
                    root.panRequested(pressScrollX + pressX - mouse.x - root.scrollX)
            }
            onReleased: function(mouse) {
                if (!isDragging) {
                    if (!audioPlayer || audioPlayer.duration <= 0) return
                    var ratio = (mouse.x + root.scrollX + 0) / timelineInner.width
                    var targetMs = Math.max(0, Math.min(audioPlayer.duration, ratio * audioPlayer.duration))
                    audioPlayer.setPosition(targetMs)
                }
                isDragging = false
            }
            // Prevent right-click issues
            acceptedButtons: Qt.LeftButton
            // 滚轮缩放
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