import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: root

    width: 1200
    height: 800
    // visible: true  // 测试直接显示
    title: "谱面详情"
    color: "#FFFFFF"

    property int selectedCourseIndex: 0

    // --- 模拟数据 ---
    property string realTitle: "测试歌曲"
    property real realBpm: 180
    property string realGenre: "动漫"
    property var realCourses: [
        {
            course: "Easy",
            level: 3,
            notes: [
                "1000100010001000",
                "1111222211112222",
                "1234123412341234"
            ]
        },
        {
            course: "Normal",
            level: 5,
            notes: [
                "1111222233334444",
                "1234123412341234",
                "5555000088880000"
            ]
        },
        {
            course: "Hard",
            level: 8,
            notes: [
                "1234123412341234",
                "5555555588888888",
                "7777111122228888"
            ]
        }
    ]

    function parseMeasure(line) {
        var digits = []
        for (var i = 0; i < line.length; i++) {
            var c = line[i]
            if (c >= "0" && c <= "9") digits.push(parseInt(c))
        }
        var total = digits.length
        if (total <= 0) return { notes: [], totalDigits: 0, slots: 8 }

        var notes = []
        for (var i = 0; i < total; i++) {
            var type = digits[i]
            if (type !== 0) {
                notes.push({
                    type: type,
                    position: i / total * 8  // 0~8 之间的位置（映射到8个八分音符槽位）
                })
            }
        }

        return {
            notes: notes,
            totalDigits: total,
            slots: 8
        }
    }

    function noteEmoji(type) {
        switch(type) {
        case 1: return "🔴"
        case 2: return "🔵"
        case 3: return "🟥"
        case 4: return "🟦"
        case 5: return "🟨"
        case 6: return "🟧"
        case 7: return "🎈"
        case 8: return "🏁"
        default: return "·"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ── 歌曲信息 ──
        GroupBox {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 4
                Text { text: realTitle; font.pixelSize: 28; font.bold: true; color: "#222" }
                Text { text: "BPM : " + realBpm.toFixed(1); color: "#E60012"; font.pointSize: 14 }
                Text { text: "Genre : " + realGenre; color: "#4A90D9"; font.pointSize: 13 }
            }
        }

        // ── 难度按钮 ──
        GroupBox {
            Layout.fillWidth: true
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: realCourses
                    delegate: Button {
                        text: modelData.course + " ★" + modelData.level
                        highlighted: index === root.selectedCourseIndex
                        onClicked: root.selectedCourseIndex = index
                        background: Rectangle {
                            radius: 6
                            color: index === root.selectedCourseIndex ? "#E60012" : "#F5F5F5"
                            border.color: index === root.selectedCourseIndex ? "#E60012" : "#DDD"
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            color: index === root.selectedCourseIndex ? "white" : "#333"
                            font.bold: true
                            font.pointSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        // ── 谱面预览 ──
        GroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollView {
                anchors.fill: parent
                clip: true
                Column {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: realCourses[root.selectedCourseIndex].notes
                        delegate: Rectangle {
                            width: parent.width - 10
                            height: 72
                            color: index % 2 ? "#F5F5F5" : "#FFFFFF"
                            Column {
                                anchors.fill: parent
                                // 上面：小节编号（浅灰蓝背景）
                                Rectangle {
                                    width: parent.width
                                    height: 24
                                    color: "#E8EDF2"
                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "第 " + (index + 1) + " 小节"
                                        color: "#5A7D9A"
                                        font.pointSize: 10
                                        font.bold: true
                                    }
                                }
                                // 下面：音符 emoji + 8个固定八分音符分隔线
                                Item {
                                    id: measureArea
                                    width: parent.width
                                    height: 48
                                    property int leftPadding: 16
                                    property int rightPadding: 16
                                    property real usableWidth: parent.width - leftPadding - rightPadding
                                    property real slotWidth: usableWidth / 8  // 每个八分音符槽宽度

                                    // 9条固定分隔线（0 到 8，共8个八分音符间隔）
                                    // 线0=小节线(粗), 线2/4/6=拍线(细), 线1/3/5/7=八分线(极细), 线8=小节线(粗)
                                    Repeater {
                                        model: 9
                                        delegate: Rectangle {
                                            x: (measureArea.leftPadding + index * measureArea.slotWidth - (width / 2)) * 10
                                            y: 2
                                            height: 44
                                            width: (index === 0 || index === 8) ? 3 : (index % 2 === 0) ? 2 : 1
                                            color: (index === 0 || index === 8) ? "#888" : (index % 2 === 0) ? "#AAA" : "#DDD"
                                            z: 0
                                        }
                                    }

                                    // 根据计算出的位置摆放音符
                                    Repeater {
                                        model: root.parseMeasure(modelData).notes
                                        delegate: Text {
                                            x: (measureArea.leftPadding + modelData.position / 8 * measureArea.usableWidth - 14) * 10
                                            y: (measureArea.height - 28) / 2
                                            text: root.noteEmoji(modelData.type)
                                            font.pixelSize: 28
                                            font.family: "Segoe UI Emoji"
                                            width: 28
                                            height: 28
                                            z: 2
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}