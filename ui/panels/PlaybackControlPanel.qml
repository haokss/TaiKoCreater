import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs

// 播放控制面板
Rectangle {
    id: root
    property int myIdx: 1
    property Item dockArea: null

    signal dragReleased
    signal tjaLoaded(var data)

    width: 760
    height: 200
    radius: 8
    color: "#162132"
    border.color: dragArea.drag.active ? "#FF9800" : "#273247"
    border.width: dragArea.drag.active ? 2 : 1
    z: dragArea.drag.active ? 10 : 1
    Behavior on x {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    // 格式化时间 mm:ss
    function formatTime(ms) {
        if (!ms || ms <= 0)
            return "00:00";
        var totalSec = Math.floor(ms / 1000);
        var min = Math.floor(totalSec / 60);
        var sec = totalSec % 60;
        return (min < 10 ? "0" : "") + min + ":" + (sec < 10 ? "0" : "") + sec;
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ======================
        // 顶部
        // ======================

        Row {
            width: parent.width
            spacing: 20

            // 左侧时间显示
            Column {
                spacing: 2

                Text {
                    text: root.formatTime(audioPlayer.position)
                    font.pixelSize: 34
                    font.bold: true
                    color: "#E6E8F0"
                }

                Text {
                    text: root.formatTime(audioPlayer.duration)
                    font.pixelSize: 18
                    color: "#8FA6C6"
                }
            }

            Item {
                width: 1
                height: 60
            }

            // 右侧控制区
            Column {
                spacing: 12

                // 音量
                Row {
                    spacing: 10

                    Text {
                        text: "音量"
                        width: 40
                        color: "#8FA6C6"
                        font.pixelSize: 12
                    }

                    Slider {
                        id: volumeSlider
                        width: 180

                        from: 0
                        to: 1

                        value: audioPlayer.volume

                        onValueChanged: {
                            if (Math.abs(audioPlayer.volume - value) > 0.005)
                                audioPlayer.volume = value;
                        }
                    }

                    Text {
                        text: Math.round(audioPlayer.volume * 100) + "%"
                        width: 40
                        color: "#C9D2E3"
                    }
                }

                // 播放速度
                Row {
                    spacing: 10

                    Text {
                        text: "倍速"
                        width: 40
                        color: "#8FA6C6"
                        font.pixelSize: 12
                    }

                    Slider {
                        id: speedSlider
                        width: 180

                        from: 0.5
                        to: 2.0

                        value: 1.0
                    }

                    Text {
                        text: speedSlider.value.toFixed(2) + "x"
                        width: 45
                        color: "#C9D2E3"
                    }
                }
            }
        }

        // ======================
        // 中间按钮栏
        // ======================

        Row {
            spacing: 10

            Repeater {
                model: [
                    {
                        icon: "⏮",
                        color: "#6DA9FF"
                    },
                    {
                        icon: "▶",
                        color: "#43C985"
                    },
                    {
                        icon: "⏸",
                        color: "#FF9800"
                    },
                    {
                        icon: "⏭",
                        color: "#6DA9FF"
                    },
                    {
                        icon: "↻",
                        color: "#4DA3FF"
                    },
                    {
                        icon: "◇",
                        color: "#5B657A"
                    }
                ]

                delegate: Rectangle {
                    width: 42
                    height: 42
                    radius: 8

                    color: modelData.color

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: "white"
                        font.pixelSize: 18
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            switch (index) {
                            case 0:
                                audioPlayer.setPosition(Math.max(0, audioPlayer.position - 5000));
                                break;
                            case 1:
                                audioPlayer.play();
                                break;
                            case 2:
                                audioPlayer.pause();
                                break;
                            case 3:
                                audioPlayer.setPosition(Math.min(audioPlayer.duration, audioPlayer.position + 5000));
                                break;
                            case 4:
                                audioPlayer.stop();
                                audioPlayer.play();
                                break;
                            case 5:
                                break;
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: "#243450"
        }

        // ======================
        // 导入区域
        // ======================

        Row {
            spacing: 8

            Button {
                text: "导入 OGG"
                onClicked: oggDialog.open()
            }

            Button {
                text: "导入 TJA"
                onClicked: tjaDialog.open()
            }
        }

    }

    // ── OGG 文件对话框 ──
    FileDialog {
        id: oggDialog
        title: "选择 OGG 音频文件"
        nameFilters: ["OGG 音频 (*.ogg)", "所有音频 (*.mp3 *.wav *.ogg *.flac)", "所有文件 (*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            audioPlayer.loadFile(selectedFile);
            console.log("AudioPlayer: 已加载", selectedFile);
        }
    }

    // ── TJA 文件对话框 ──
    FileDialog {
        id: tjaDialog
        title: "选择 TJA 谱面文件"
        nameFilters: ["TJA 谱面 (*.tja)", "所有文件 (*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            if (typeof songModel !== "undefined" && songModel) {
                var data = songModel.loadTJAFile(String(selectedFile));
                if (data && data.measureLines) {
                    console.log("TJA loaded:", data.course, "★" + data.level, data.measureLines.length, "measures");
                    root.tjaLoaded(data);
                }
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: Qt.binding(function () {
            return dockArea ? Math.max(0, dockArea.width - root.width) : 0;
        })
        drag.maximumY: Qt.binding(function () {
            return dockArea ? Math.max(0, dockArea.height - root.height) : 0;
        })
        onReleased: root.dragReleased()
    }
}
