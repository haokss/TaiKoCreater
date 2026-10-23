import QtQuick 2.15

// 歌曲信息面板
Rectangle {
    id: root
    property int myIdx: 0
    property Item dockArea: null

    signal dragReleased()

    width: 580; height: 200; radius: 8
    color: "#162132"
    border.color: dragArea.drag.active ? "#E60012" : "#273247"
    border.width: dragArea.drag.active ? 2 : 1
    z: dragArea.drag.active ? 10 : 1
    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    function formatTime(ms) {
        if (!ms || ms <= 0) return "--:--"
        var totalSec = Math.floor(ms / 1000)
        var min = Math.floor(totalSec / 60)
        var sec = totalSec % 60
        return min + ":" + (sec < 10 ? "0" : "") + sec
    }

    function formatFileName(url) {
        var src = url ? url.toString() : ""
        if (!src) return ""
        var parts = src.split("/")
        var name = parts[parts.length - 1]
        // URL decode
        return decodeURIComponent(name)
    }

Column {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 10

    Row {
        spacing: 14

        // 封面
        Rectangle {
            width: 96
            height: 96
            radius: 8
            color: "#1D2C44"
            border.color: "#273247"

            Image {
                anchors.fill: parent
                anchors.margins: 1
                fillMode: Image.PreserveAspectCrop

                // 后续替换成歌曲封面
                source: songCoverSource || ""
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !parent.children[0].visible
                text: "No Cover"
                color: "#5B657A"
                font.pixelSize: 12
            }
        }

        Column {
            spacing: 6
            width: root.width - 140

            // 歌曲名
            Text {
                text: root.formatFileName(audioPlayer.source)
                font.pixelSize: 24
                font.bold: true
                color: "#E6E8F0"

                width: parent.width
                elide: Text.ElideRight
            }

            // 艺术家
            Text {
                text: "Unknown Artist"
                font.pixelSize: 14
                color: "#8FA6C6"

                width: parent.width
                elide: Text.ElideRight
            }

            // 标签区域
            Row {
                spacing: 6

                Rectangle {
                    radius: 4
                    color: "#243450"
                    height: 22
                    width: genreText.implicitWidth + 14

                    Text {
                        id: genreText
                        anchors.centerIn: parent
                        text: "J-POP"
                        color: "#8FA6C6"
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                Text {
                    text: "★ 8"
                    color: "#FF3B7A"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: "#273247"
    }

    // 底部统计信息
    Row {
        width: parent.width
        spacing: 40

        Column {
            spacing: 2

            Text {
                text: "BPM"
                font.pixelSize: 11
                color: "#5B657A"
            }

            Text {
                text: audioPlayer.detectedBpm > 0
                      ? Math.round(audioPlayer.detectedBpm)
                      : "--"
                font.pixelSize: 20
                font.bold: true
                color: "#E6E8F0"
            }
        }

        Column {
            spacing: 2

            Text {
                text: "拍号"
                font.pixelSize: 11
                color: "#5B657A"
            }

            Text {
                text: "4/4"
                font.pixelSize: 20
                font.bold: true
                color: "#E6E8F0"
            }
        }

        Column {
            spacing: 2

            Text {
                text: "总时长"
                font.pixelSize: 11
                color: "#5B657A"
            }

            Text {
                text: root.formatTime(audioPlayer.duration)
                font.pixelSize: 20
                font.bold: true
                color: "#E6E8F0"
            }
        }

        Column {
            spacing: 2

            Text {
                text: "物量"
                font.pixelSize: 11
                color: "#5B657A"
            }

            Text {
                text: noteCount > 0 ? noteCount : "--"
                font.pixelSize: 20
                font.bold: true
                color: "#E6E8F0"
            }
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