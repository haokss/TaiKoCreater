import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

// ═══════════════════════════════════════════════════════════════════
// 谱面详情（暗色）
//
// 对外契约保持不变，main.qml / AIGeneratePage.qml 无需改动：
//   realTitle / realBpm / realGenre / realCourses / selectedCourseIndex
//   realCourses: [{ course: "Oni", level: 8, notes: ["1010...", ...] }]
//
// 音符贴图取自 res/Notes.png 雪碧图（带 alpha），坐标由脚本实测。
// ═══════════════════════════════════════════════════════════════════
Window {
    id: root

    width: 1280
    height: 880
    minimumWidth: 940
    minimumHeight: 560
    title: qsTr("谱面详情")
    color: "#0D1117"
    flags: Qt.Window | Qt.FramelessWindowHint

    // ── 对外数据 ──
    property string realTitle: ""
    property real realBpm: 180
    property string realGenre: ""
    property var realCourses: []
    property int selectedCourseIndex: 0

    // ── 配色（与主窗口一致）──
    readonly property color bgColor: "#0D1117"
    readonly property color cardColor: "#162132"
    readonly property color panelColor: "#111827"
    readonly property color borderColor: "#273247"
    readonly property color textPrimary: "#E6E8F0"
    readonly property color textSecondary: "#8FA6C6"
    readonly property color goldColor: "#FFC542"

    readonly property var currentCourse: (realCourses.length > 0 && selectedCourseIndex >= 0 && selectedCourseIndex < realCourses.length)
                                         ? realCourses[selectedCourseIndex] : null
    readonly property var currentNotes: currentCourse ? (currentCourse.notes || []) : []
    readonly property int totalNotes: countNotes(currentNotes)
    readonly property int measureCount: currentNotes.length
    readonly property real durationSec: (realBpm > 0 && measureCount > 0) ? measureCount * 240 / realBpm : 0
    readonly property real avgNps: durationSec > 0 ? totalNotes / durationSec : 0

    // ── 工具函数 ──
    function countNotes(lines) {
        var n = 0
        if (!lines) return 0
        for (var i = 0; i < lines.length; ++i) {
            var s = lines[i]
            for (var j = 0; j < s.length; ++j) {
                var c = s.charAt(j)
                if (c >= "1" && c <= "7") n++
                else if (c === "9") n++
            }
        }
        return n
    }

    // 把一小节字符串拆成音符位置 + 连打区间
    function parseMeasure(line) {
        var notes = []
        var rolls = []
        if (!line) return { total: 0, notes: notes, rolls: rolls }
        var clean = ""
        for (var i = 0; i < line.length; ++i) {
            var ch = line.charAt(i)
            if (ch >= "0" && ch <= "9") clean += ch
        }
        var total = clean.length
        if (total === 0) return { total: 0, notes: notes, rolls: rolls }

        var openAt = -1
        for (var k = 0; k < total; ++k) {
            var d = clean.charAt(k)
            if (d === "0") continue
            var pos = k / total
            if (d === "8") {
                if (openAt >= 0) {
                    rolls.push({ from: openAt, to: pos })
                    openAt = -1
                }
                continue
            }
            notes.push({ pos: pos, type: d })
            // 气球(7)/地瓜(9) 只画图标，不拉连打条
            if (d === "5" || d === "6") openAt = pos
        }
        if (openAt >= 0) rolls.push({ from: openAt, to: 1.0 })
        return { total: total, notes: notes, rolls: rolls }
    }

    // 音符 → 雪碧图裁剪区域（res/Notes.png 实测坐标，第 1 行）
    function spriteFor(type) {
        switch (type) {
        case "1": return Qt.rect(158, 30, 71, 70)    // 咚
        case "2": return Qt.rect(288, 30, 71, 70)    // 咔
        case "3": return Qt.rect(401, 12, 106, 106)  // 咚（大）
        case "4": return Qt.rect(531, 12, 106, 106)  // 咔（大）
        case "5": return Qt.rect(678, 30, 71, 70)    // 连打开始
        case "6": return Qt.rect(1051, 12, 106, 106) // 大连打开始
        case "7": return Qt.rect(1458, 30, 177, 70)  // 气球
        case "9": return Qt.rect(1458, 30, 177, 70)  // 地瓜
        default:  return Qt.rect(158, 30, 71, 70)
        }
    }

    function noteSize(type) {
        return (type === "3" || type === "4" || type === "6") ? 34 : 24
    }

    // 气球/地瓜是横向长条，按原始比例（177x70）给宽度
    function noteWidth(type) {
        if (type === "7" || type === "9") return 48
        return noteSize(type)
    }

    function courseColor(course) {
        var c = (course || "").toLowerCase()
        if (c.indexOf("easy") === 0) return "#5CB85C"
        if (c.indexOf("normal") === 0) return "#4A90D9"
        if (c.indexOf("hard") === 0) return "#F0AD4E"
        if (c.indexOf("oni") === 0) return "#E0454B"
        if (c.indexOf("ura") === 0 || c.indexOf("extra") === 0) return "#9B59B6"
        return "#8FA6C6"
    }

    function formatDuration(sec) {
        if (sec <= 0) return "--:--"
        var m = Math.floor(sec / 60)
        var s = Math.round(sec % 60)
        if (s === 60) { m += 1; s = 0 }
        return m + ":" + (s < 10 ? "0" + s : s)
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgColor
        border.width: 1
        border.color: "#2A3A54"

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ═════════════════ 标题栏 ═════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: "#1E1E2E"

                MouseArea {
                    anchors.fill: parent
                    onPressed: root.startSystemMove()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 56
                    spacing: 10

                    Rectangle {
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: root.courseColor(root.currentCourse ? root.currentCourse.course : "")
                    }

                    Text {
                        text: qsTr("谱面详情")
                        color: root.textSecondary
                        font.pointSize: 10
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    width: 46
                    height: parent.height
                    anchors.right: parent.right
                    color: closeArea.containsMouse ? "#E81123" : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeArea.containsMouse ? "#FFFFFF" : "#CCCCCC"
                        font.pointSize: 11
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // ═════════════════ 歌曲信息 ═════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 116
                color: root.cardColor

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: root.borderColor
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    spacing: 28

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: root.realTitle.length > 0 ? root.realTitle : qsTr("（未选择歌曲）")
                            color: root.textPrimary
                            font.pointSize: 22
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            spacing: 10

                            Rectangle {
                                visible: root.realGenre.length > 0
                                implicitWidth: genreText.implicitWidth + 20
                                implicitHeight: 22
                                radius: 11
                                color: "#1D2C44"
                                border.width: 1
                                border.color: "#2E4160"

                                Text {
                                    id: genreText
                                    anchors.centerIn: parent
                                    text: root.realGenre
                                    color: root.textSecondary
                                    font.pointSize: 9
                                }
                            }

                            Text {
                                text: qsTr("BPM ") + (root.realBpm > 0 ? root.realBpm.toFixed(1) : "--")
                                color: root.goldColor
                                font.pointSize: 12
                                font.bold: true
                            }

                            Text {
                                text: qsTr("时长 ") + root.formatDuration(root.durationSec)
                                color: root.textSecondary
                                font.pointSize: 11
                            }
                        }
                    }

                    // 难度徽章
                    Rectangle {
                        visible: root.currentCourse !== null
                        implicitWidth: 112
                        implicitHeight: 72
                        radius: 10
                        color: "#0F1A2B"
                        border.width: 2
                        border.color: root.courseColor(root.currentCourse ? root.currentCourse.course : "")

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.currentCourse ? root.currentCourse.course : ""
                                color: root.courseColor(root.currentCourse ? root.currentCourse.course : "")
                                font.pointSize: 11
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "★ " + (root.currentCourse ? root.currentCourse.level : 0)
                                color: root.textPrimary
                                font.pointSize: 20
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // ═════════════════ 难度切换 ═════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: root.panelColor

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    spacing: 8

                    Repeater {
                        model: root.realCourses

                        delegate: Rectangle {
                            implicitWidth: tabLabel.implicitWidth + 32
                            implicitHeight: 32
                            radius: 16
                            color: index === root.selectedCourseIndex
                                   ? root.courseColor(modelData.course)
                                   : (tabArea.containsMouse ? "#1B2A42" : "transparent")
                            border.width: 1
                            border.color: index === root.selectedCourseIndex
                                          ? root.courseColor(modelData.course) : root.borderColor

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: modelData.course + "  ★" + modelData.level
                                color: index === root.selectedCourseIndex ? "#0D1117" : root.textSecondary
                                font.pointSize: 10
                                font.bold: index === root.selectedCourseIndex
                            }

                            MouseArea {
                                id: tabArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedCourseIndex = index
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: root.realCourses.length === 0
                        text: qsTr("没有可显示的难度")
                        color: root.textSecondary
                        font.pointSize: 10
                    }
                }
            }

            // ═════════════════ 统计条 ═════════════════
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: root.bgColor

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: root.borderColor
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 28
                    anchors.rightMargin: 28
                    spacing: 34

                    Repeater {
                        model: [
                            { k: qsTr("音符"), v: root.totalNotes.toString() },
                            { k: qsTr("小节"), v: root.measureCount.toString() },
                            { k: qsTr("平均密度"), v: root.avgNps.toFixed(1) + " NPS" },
                            { k: qsTr("BPM"), v: root.realBpm > 0 ? root.realBpm.toFixed(0) : "--" }
                        ]

                        delegate: Column {
                            spacing: 2
                            Text {
                                text: modelData.k
                                color: root.textSecondary
                                font.pointSize: 9
                            }
                            Text {
                                text: modelData.v
                                color: root.textPrimary
                                font.pointSize: 15
                                font.bold: true
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: qsTr("滚轮浏览 · Esc 关闭")
                        color: "#4A5C77"
                        font.pointSize: 9
                    }
                }
            }

            // ═════════════════ 谱面区 ═════════════════
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: chartView
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 34
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    clip: true
                    spacing: 2
                    model: root.currentNotes
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    delegate: Rectangle {
                        id: measureRow
                        // 让出右侧滚动条的位置，否则每小节的音符数会被压掉
                        width: chartView.width - 26
                        height: 46
                        radius: 4
                        color: index % 2 === 0 ? "#131D2C" : "#162132"

                        property var parsed: root.parseMeasure(modelData)

                        // 小节号
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: ("000" + (index + 1)).slice(-3)
                            color: "#5A6B85"
                            font.family: "Consolas, monospace"
                            font.pointSize: 9
                        }

                        // 谱面网格 + 音符
                        Item {
                            id: lane
                            anchors.left: parent.left
                            anchors.leftMargin: 78
                            anchors.right: parent.right
                            anchors.rightMargin: 70
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            clip: true

                            readonly property real pad: 22
                            readonly property real usable: Math.max(1, width - 2 * pad)

                            // 位置 0~1 映射到内缩后的轨道，避免首尾音符被裁半
                            function xFor(pos) {
                                return pad + pos * usable
                            }

                            Repeater {
                                model: 5
                                delegate: Rectangle {
                                    x: lane.xFor(index / 4) - width / 2
                                    width: (index === 0 || index === 4) ? 2 : 1
                                    height: parent.height
                                    color: (index === 0 || index === 4) ? "#2E4160" : "#1E2B40"
                                }
                            }

                            Repeater {
                                model: measureRow.parsed.rolls
                                delegate: Rectangle {
                                    x: lane.xFor(modelData.from)
                                    width: Math.max(6, (modelData.to - modelData.from) * lane.usable)
                                    height: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: root.goldColor
                                    opacity: 0.85
                                    radius: 5
                                }
                            }

                            Repeater {
                                model: measureRow.parsed.notes
                                delegate: Image {
                                    readonly property int sz: root.noteSize(modelData.type)
                                    readonly property int wd: root.noteWidth(modelData.type)
                                    source: "../../res/Notes.png"
                                    sourceClipRect: root.spriteFor(modelData.type)
                                    width: wd
                                    height: sz
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    x: lane.xFor(modelData.pos) - width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // 小节内音符数
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: measureRow.parsed.notes.length
                            color: "#4A5C77"
                            font.family: "Consolas, monospace"
                            font.pointSize: 9
                        }
                    }
                }

                // 空状态
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.currentNotes.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("没有谱面数据")
                        color: root.textSecondary
                        font.pointSize: 13
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("在列表里点击歌曲，或让 AI 生成一份谱面")
                        color: "#4A5C77"
                        font.pointSize: 10
                    }
                }
            }
        }
    }
}
