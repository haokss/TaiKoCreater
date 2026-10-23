import QtQuick 2.15
import QtQuick.Controls 2.15
import "../NoteSprites.js" as NoteSprites

Rectangle {
    id: root
    property int myIdx: 3
    property Item dockArea: null
    property var chartData: null

    signal dragReleased
    signal chartModified

    width: 1200
    height: 340
    radius: 8
    color: "#162132"
    border.color: dragArea.drag.active ? "#4A90D9" : "#273247"
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

    property real contentWidth: width - 24
    property string timeSignature: "4/4"
    property var measures: ["10203040", "50000060", "11112222", "30040050", "12030405"]

    onChartDataChanged: {
        if (chartData && chartData.measureLines && chartData.measureLines.length > 0) {
            var copy = [];
            for (var i = 0; i < chartData.measureLines.length; i++)
                copy.push(String(chartData.measureLines[i]));
            measures = copy;
        }
    }

    function noteTypeAt(line, idx) {
        var c = line[idx];
        return (c >= "1" && c <= "9") ? parseInt(c) : 0;
    }
    function noteList(line) {
        var list = [];
        for (var i = 0; i < line.length; i++) {
            var t = noteTypeAt(line, i);
            if (t >= 1 && t <= 8)
                list.push({
                    charIdx: i,
                    type: t
                });
        }
        return list;
    }
    function moveNote(measureIdx, oldCharIdx, newCharIdx) {
        var line = measures[measureIdx];
        var arr = line.split('');
        var nt = noteTypeAt(line, oldCharIdx);
        if (nt === 0)
            return;
        newCharIdx = Math.max(0, Math.min(arr.length - 1, newCharIdx));
        arr[oldCharIdx] = "0";
        arr[newCharIdx] = String(nt);
        var copy = measures.slice();
        copy[measureIdx] = arr.join('');
        measures = copy;
        chartModified();
    }
    function insertNote(measureIdx, newCharIdx, noteType) {
        var line = measures[measureIdx];
        var arr = line.split('');
        newCharIdx = Math.max(0, Math.min(arr.length - 1, newCharIdx));
        arr[newCharIdx] = String(noteType);
        var copy = measures.slice();
        copy[measureIdx] = arr.join('');
        measures = copy;
        chartModified();
    }
    function slotX(charIdx, totalSlots) {
        var uW = root.contentWidth;
        if (totalSlots <= 1)
            return uW / 2 - 12;
        var step = uW / (totalSlots - 1);
        return charIdx * step - 12;
    }
    function xToSlot(pxX, totalSlots) {
        var uW = root.contentWidth;
        if (totalSlots <= 1)
            return 0;
        var step = uW / (totalSlots - 1);
        return Math.max(0, Math.min(totalSlots - 1, Math.round((pxX + 12) / step)));
    }

    // ── 手动打印槽位信息（点击按钮触发） ──
    function dumpSlotInfo() {
        var lines = [];
        lines.push("══════ 槽位信息打印 ══════");
        lines.push("面板宽=" + root.width + "px, 内容宽=" + root.contentWidth.toFixed(0) + "px, 拍号=" + timeSignature);
        for (var mi = 0; mi < measures.length; mi++) {
            var line = measures[mi];
            var n = line.length;
            var step = n > 1 ? root.contentWidth / (n - 1) : 0;
            lines.push("── 小节" + (mi + 1) + ": " + n + "槽位 (步长=" + step.toFixed(1) + "px) ──");
            for (var si = 0; si < n; si++) {
                var sx = root.slotX(si, n) + 12;
                var nt = noteTypeAt(line, si);
                lines.push("  槽" + si + " -> x=" + sx.toFixed(1) + "px  [" + (nt > 0 ? "音符" + nt : "空") + "]");
            }
        }
        lines.push("════════════════════════");
        var msg = lines.join("\n");
        // 同时输出到 logger 和 console
        logger.addLog(msg);
        console.log(msg);
    }

    // ── 拖拽区域（标题栏底部兜底，先定义确保 z 低于标题栏） ──
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

    // ── 标题栏 ──
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 30
        radius: 8
        color: "#111827"
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 8
            color: "#4A90D9"
        }
        Row {
            anchors.centerIn: parent
            spacing: 12
            Text {
                text: (chartData && chartData.course)
                      ? "编辑区 - " + chartData.course + " ★" + chartData.level
                      : "编辑区"
                color: "#C9D2E3"
                font.bold: true
                font.pointSize: 11
            }
            Text {
                text: "拍号: " + timeSignature
                color: "#FFD54F"
                font.pointSize: 10
            }
            Rectangle {
                width: 60
                height: 20
                radius: 4
                color: "#FFD54F"
                Text {
                    anchors.centerIn: parent
                    text: "打印槽位"
                    font.pointSize: 8
                    color: "#C9D2E3"
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dumpSlotInfo()
                }
            }
        }
    }

    // ── 根级 DropArea（绕过 ScrollView 内部 Flickable 的拦截） ──
    DropArea {
        id: rootDropArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 34
        anchors.bottom: parent.bottom
        keys: ["text/x-note-type"]

        onDropped: function(drop) {
            // 计算 Y 对应的小节索引
            // ScrollView 上边距 34px (30 标题栏 + 4 间距)
            // 每小节: 52px 高度 + 4px 间距 = 56px
            var scrollY = drop.y - 34
            var measureIdx = Math.floor(scrollY / 56)

            if (measureIdx < 0 || measureIdx >= measures.length)
                return

            var lineData = measures[measureIdx]
            var noteType = parseInt(drop.getDataAsString("text/x-note-type"))
            if (!noteType || noteType < 1 || noteType > 8)
                return

            // 计算 X 对应的槽位
            // ScrollView 左边距 4px，内容区内 measureItem 从 x=0 开始
            var localX = drop.x - 4
            var newIdx = root.xToSlot(localX, lineData.length)

            root.insertNote(measureIdx, newIdx, noteType)
            drop.accepted = true
        }
    }

    // ── 谱面滚动区域 ──
    ScrollView {
        anchors.fill: parent
        anchors.topMargin: 34
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4
        clip: true

        Column {
            id: measureColumn
            width: parent ? parent.width - 16 : 550
            spacing: 4

            Repeater {
                model: measures
                delegate: Rectangle {
                    id: measureItem
                    property int measureIdx: index
                    property string lineData: modelData
                    property var notes: root.noteList(lineData)

                    width: measureColumn.width
                    height: 52
                    color: index % 2 ? "#1D2C44" : "#162132"
                    onLineDataChanged: notes = root.noteList(lineData)

                    Rectangle {
                        width: parent.width
                        height: 20
                        color: "#1D2C44"
                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 12
                            Text {
                                text: "第 " + (index + 1) + " 小节"
                                color: "#8FA6C6"
                                font.pointSize: 9
                                font.bold: true
                            }
                            Text {
                                text: "(" + lineData.length + " 槽位)"
                                color: "#5B657A"
                                font.pointSize: 8
                            }
                        }
                    }

                    Item {
                        id: noteRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 20
                        height: 32

                        Repeater {
                            model: notes
                            Image {
                                id: noteImg
                                property int charIdx: modelData.charIdx
                                property int noteType: modelData.type
                                x: root.slotX(charIdx, lineData.length)
                                y: 4
                                source: "../../res/Notes.png"
                                sourceClipRect: NoteSprites.clipFor(noteType)
                                width: NoteSprites.widthFor(noteType)
                                height: NoteSprites.sizeFor(noteType)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                                z: handler.drag.active ? 10 : 1

                                MouseArea {
                                    id: handler
                                    anchors.fill: parent
                                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    drag.target: parent
                                    drag.axis: Drag.XAxis
                                    drag.minimumX: 0
                                    drag.maximumX: root.contentWidth - 24
                                    onReleased: {
                                        var n = lineData.length;
                                        var newIdx = root.xToSlot(noteImg.x, n);
                                        root.moveNote(measureIdx, charIdx, newIdx);
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
