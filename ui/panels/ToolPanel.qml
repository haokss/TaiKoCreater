import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../NoteSprites.js" as NoteSprites

// 音符选择工具面板 — 支持拖拽音符到编辑区，每行一个音符（图标左 + 文本右）
Rectangle {
    id: root
    property int myIdx: 5
    property Item dockArea: null

    signal dragReleased()
    signal noteSelected(int noteType)

    width: 160; height: 330; radius: 8
    color: "#162132"
    border.color: dragArea.drag.active ? "#43C985" : "#273247"
    border.width: dragArea.drag.active ? 2 : 1
    z: dragArea.drag.active ? 10 : 1
    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    property int selectedNote: 1

    function selectNote(type) {
        selectedNote = type
        noteSelected(type)
    }

    Rectangle {
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        height: 30; radius: 8; color: "#111827"
        Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 8; color: "#43C985" }
        Text { anchors.centerIn: parent; text: "音符工具"; color: "#C9D2E3"; font.bold: true; font.pointSize: 11 }
    }

    // ── 音符列表（每行一个，图标左 + 文本右） ──
    ScrollView {
        anchors.top: parent.top; anchors.topMargin: 36
        anchors.left: parent.left; anchors.leftMargin: 6
        anchors.right: parent.right; anchors.rightMargin: 6
        anchors.bottom: parent.bottom; anchors.bottomMargin: 34
        clip: true

        Column {
            width: parent.width
            spacing: 4

            Repeater {
                model: [
                    { type: 1, label: "ドン (Don)", color: "#E60012" },
                    { type: 2, label: "カッ (Ka)", color: "#4DA3FF" },
                    { type: 3, label: "大ドン (Don)", color: "#E60012" },
                    { type: 4, label: "大カッ (Ka)", color: "#4DA3FF" },
                    { type: 5, label: "連打", color: "#FFC542" },
                    { type: 6, label: "大連打", color: "#FF9800" },
                    { type: 7, label: "風船", color: "#8B5CF6" },
                    { type: 8, label: "終了", color: "#5B657A" }
                ]

                Rectangle {
                    id: noteItem
                    width: parent.width
                    height: 28
                    radius: 6
                    color: root.selectedNote === modelData.type ? modelData.color : "#1D2C44"
                    border.color: root.selectedNote === modelData.type ? modelData.color : "#273247"
                    border.width: root.selectedNote === modelData.type ? 2 : 1
                    scale: root.selectedNote === modelData.type ? 1.03 : 1.0

                    Behavior on scale   { NumberAnimation { duration: 120 } }
                    Behavior on color   { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    // 拖拽属性
                    Drag.active: dragHandler.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.MoveAction
                    Drag.mimeData: { "text/x-note-type": modelData.type }
                    Drag.source: root

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 8
                        spacing: 8

                        Image {
                            source: "../../res/Notes.png"
                            sourceClipRect: NoteSprites.clipFor(modelData.type)
                            width: 20; height: 20
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                        }
                        Text {
                            text: modelData.label
                            font.pointSize: 9
                            color: root.selectedNote === modelData.type ? "white" : "#C9D2E3"
                            font.bold: root.selectedNote === modelData.type
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: dragHandler
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        drag.target: this
                        drag.threshold: 5
                        drag.onActiveChanged: {
                            if (drag.active) {
                                drag.target = this
                            }
                        }
                        onClicked: {
                            if (!dragHandler.drag.active)
                                root.selectNote(modelData.type)
                        }
                    }
                }
            }
        }
    }

    // 当前选中提示
    Rectangle {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 16; height: 18; radius: 4
        color: "#1D2C44"
        Text {
            anchors.centerIn: parent
            text: {
                var labels = { 1:"ドン (Don)", 2:"カッ (Ka)", 3:"大ドン", 4:"大カッ",
                               5:"連打", 6:"大連打", 7:"風船", 8:"終了" }
                return "已选: " + (labels[selectedNote] || "")
            }
            font.pointSize: 8; color: "#8FA6C6"
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