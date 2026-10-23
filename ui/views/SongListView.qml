import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    color: "#111827"
    radius: 12

    border.color: "#273247"
    border.width: 1

    property bool showDebugPanel: false

    signal songClicked(string title, real bpm, string genre, var courses, int index)

    // ── 可拖动的列宽属性 ──
    property real colCheck: 36
    property real colIndex: 40
    property real colCover: 36
    property real colTitle: 244
    property real colType: 120
    property real colDuration: 60
    property real colPath: 160

    // ── 拖动状态 ──
    property string draggingCol: ""
    property real dragStartX: 0
    property real dragStartWidth: 0

    // ── 最小列宽 ──
    readonly property real minColWidth: 30
    readonly property real defaultColTitle: 244
    readonly property real defaultColType: 120
    readonly property real defaultColDuration: 60
    readonly property real defaultColPath: 160

    Component.onCompleted: {
        colTitle = defaultColTitle
        colType = defaultColType
        colDuration = defaultColDuration
        colPath = defaultColPath
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 0

        // ── 标题栏 ──
        RowLayout {
            Rectangle {
                width: 3; height: 16; radius: 2
                color: "#FF4DA6"
            }
            Label {
                text: "歌曲列表"
                color: "white"
                font.bold: true
                font.pixelSize: 16
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                width: 8; height: 8; radius: 4
                color: "#4CAF50"
                Layout.alignment: Qt.AlignVCenter
            }
            Label {
                text: songModel ? songModel.count + " 首" : "0 首"
                color: "#C9D2E3"
                font.pixelSize: 12
            }
        }

        Item { Layout.preferredHeight: 6 }

        // ── 表头 ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 8
            color: "#162132"
            border.color: "#26364A"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 0

                // 勾选
                Text {
                    Layout.preferredWidth: root.colCheck
                    text: ""
                    color: "#5B657A"; font.pixelSize: 11; font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
                ColumnSpacer {}

                // 序号
                Text {
                    Layout.preferredWidth: root.colIndex
                    text: "#"
                    color: "#5B657A"; font.pixelSize: 11; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                ColumnSpacer {}

                // 封面
                Text {
                    Layout.preferredWidth: root.colCover
                    text: ""
                    color: "#5B657A"; font.pixelSize: 11; font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
                ColumnSpacer {}

                // 歌曲标题
                Text {
                    Layout.preferredWidth: root.colTitle
                    text: "歌曲标题"
                    color: "#5B657A"; font.pixelSize: 11; font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
                ColumnDragHandle { column: "colTitle" }

                // 类型
                Text {
                    Layout.preferredWidth: root.colType
                    text: "类型"
                    color: "#5B657A"; font.pixelSize: 11; font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
                ColumnDragHandle { column: "colType" }

                // 难度（弹性）
                Text {
                    Layout.fillWidth: true
                    text: "难度"
                    color: "#5B657A"; font.pixelSize: 11; font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
                ColumnDragHandle { column: "colDuration" }

                // 时长
                Text {
                    Layout.preferredWidth: root.colDuration
                    text: "时长"
                    color: "#5B657A"; font.pixelSize: 11; font.bold: true
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                }
                ColumnDragHandle { column: "colPath" }

                // 文件路径
                Text {
                    Layout.preferredWidth: root.colPath
                    text: "文件路径"
                    color: "#5B657A"; font.pixelSize: 11; font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Item { Layout.preferredHeight: 4 }

        // ── 歌曲列表 ──
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: songModel
            clip: true
            spacing: 2

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6; radius: 3
                    color: "#3D4A5C"; opacity: 0.8
                    HoverHandler {
                        onHoveredChanged: {
                            parent.color = hovered ? "#5B6B84" : "#3D4A5C"
                            parent.implicitWidth = hovered ? 8 : 6
                        }
                    }
                }
                background: Item { implicitWidth: 6 }
            }

            delegate: Rectangle {
                property int realIdx: songModel ? (songModel.currentPage * songModel.pageSize + index) : index
                property var songCourses: courses || []
                property string coverPath: ""
                property bool coverRequested: false

                function requestCover() {
                    if (coverRequested || !title) return
                    coverRequested = true
                    appleMusic.fetchCover(title)
                }

                // 懒加载：delegate 可见后延迟请求封面
                Timer {
                    interval: 200 + index * 30
                    running: true
                    repeat: false
                    onTriggered: parent.requestCover()
                }

                // 监听封面就绪信号
                Connections {
                    target: appleMusic
                    enabled: !coverRequested || coverPath === ""
                    onCoverReady: function(t, localPath) {
                        if (t === title) {
                            coverPath = localPath ? "file:///" + localPath : ""
                        }
                    }
                }

                height: 46
                width: listView.width
                radius: 6
                color: mouseArea.containsMouse ? "#1E2D44" : (index % 2 ? "#141E2E" : "#111827")

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 0

                    // 1. 勾选框
                    CheckBox {
                        Layout.preferredWidth: root.colCheck
                        Layout.alignment: Qt.AlignVCenter
                        checked: false
                        indicator: Rectangle {
                            width: 16; height: 16; radius: 3
                            anchors.centerIn: parent
                            color: parent.checked ? "#FF4DA6" : "transparent"
                            border.color: parent.checked ? "#FF4DA6" : "#3D4A5C"
                            border.width: 1.5
                            Rectangle {
                                anchors.centerIn: parent
                                width: 8; height: 8; radius: 1
                                color: "white"
                                visible: parent.parent.checked
                            }
                        }
                    }

                    Item { Layout.preferredWidth: 4 }

                    // 2. 序号
                    Text {
                        Layout.preferredWidth: root.colIndex
                        Layout.alignment: Qt.AlignVCenter
                        text: realIdx + 1
                        color: "#5B657A"; font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item { Layout.preferredWidth: 4 }

                    // 3. 封面缩略图
                    Rectangle {
                        Layout.preferredWidth: root.colCover
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: 4
                        color: "#162132"
                        border.color: "#26364A"
                        Image {
                            anchors.fill: parent; anchors.margins: 1
                            source: coverPath || "../../res/songbg.png"
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                        }
                    }

                    Item { Layout.preferredWidth: 4 }

                    // 4. 歌曲标题
                    ColumnLayout {
                        Layout.preferredWidth: root.colTitle
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1
                        Text {
                            text: title || ""
                            font.bold: true; font.pixelSize: 12
                            color: mouseArea.containsMouse ? "#FFB300" : "#E6E8F0"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: genreTitle || genre || ""
                            font.pixelSize: 10; color: "#6B7280"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            visible: text !== ""
                        }
                    }

                    Item { Layout.preferredWidth: 4 }

                    // 5. 类型
                    Text {
                        Layout.preferredWidth: root.colType
                        Layout.alignment: Qt.AlignVCenter
                        text: genreTitle || genre || ""
                        color: "#8FA6C6"; font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Item { Layout.preferredWidth: 4 }

                    // 6. 难度标签
                    Row {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 3

                        Repeater {
                            model: songCourses
                            delegate: Rectangle {
                                height: 18
                                width: courseLabel.implicitWidth + 12
                                radius: 3
                                color: {
                                    var c = modelData.course
                                    if (c === "Oni") return "#E60012"
                                    if (c === "Hard") return "#FF9800"
                                    if (c === "Normal") return "#4CAF50"
                                    if (c === "Easy") return "#4A90D9"
                                    return "#888"
                                }
                                Text {
                                    id: courseLabel
                                    anchors.centerIn: parent
                                    text: modelData.course + " " + modelData.level
                                    color: "white"; font.pixelSize: 9; font.bold: true
                                }
                            }
                        }
                    }

                    Item { Layout.preferredWidth: 4 }

                    // 7. 时长
                    Text {
                        Layout.preferredWidth: root.colDuration
                        Layout.alignment: Qt.AlignVCenter
                        text: {
                            var sec = duration
                            if (!sec || sec <= 0) return "--:--"
                            var m = Math.floor(sec / 60)
                            var s = Math.floor(sec % 60)
                            return m + ":" + (s < 10 ? "0" : "") + s
                        }
                        color: "#8FA6C6"; font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }

                    Item { Layout.preferredWidth: 4 }

                    // 8. 文件路径
                    Text {
                        Layout.preferredWidth: root.colPath
                        Layout.alignment: Qt.AlignVCenter
                        text: filePath || ""
                        color: "#5B657A"; font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                // 左侧选中指示条
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 4; anchors.bottomMargin: 4
                    width: 3
                    color: mouseArea.containsMouse ? "#FFB300" : "transparent"
                    radius: 2
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.songClicked(title, bpm, genreTitle || genre || "", songCourses, realIdx)
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 6 }

        // ── 分页导航栏 ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 8
            color: "#162132"
            border.color: "#26364A"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 8

                Text {
                    text: "共 " + (songModel ? songModel.totalCount : 0) + " 条 / "
                          + (songModel ? songModel.totalPages : 0) + " 页"
                    color: "#8FA6C6"; font.pixelSize: 11
                }

                Item { Layout.fillWidth: true }

                Text { text: "每页:"; color: "#6B7280"; font.pixelSize: 11 }
                ComboBox {
                    id: pageSizeCombo
                    model: [10, 20, 50, 100, 200]
                    currentIndex: {
                        var ps = songModel ? songModel.pageSize : 50
                        var idx = model.indexOf(ps)
                        return idx >= 0 ? idx : 2
                    }
                    onActivated: {
                        if (songModel) songModel.pageSize = currentValue
                    }
                    Layout.preferredWidth: 80; font.pixelSize: 11
                }

                Rectangle { width: 1; height: 20; color: "#26364A" }

                RowLayout {
                    spacing: 4
                    PageNavButton { text: "|<"; enabled: songModel ? songModel.currentPage > 0 : false; onClicked: { if (songModel) songModel.goToPage(0) } }
                    PageNavButton { text: "<"; enabled: songModel ? songModel.currentPage > 0 : false; onClicked: { if (songModel) songModel.prevPage() } }
                    Text {
                        text: (songModel ? (songModel.currentPage + 1) : 0) + " / " + (songModel ? songModel.totalPages : 0)
                        color: "#C9D2E3"; font.pixelSize: 12; font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.preferredWidth: 64
                    }
                    PageNavButton { text: ">"; enabled: songModel ? (songModel.currentPage < songModel.totalPages - 1) : false; onClicked: { if (songModel) songModel.nextPage() } }
                    PageNavButton { text: ">|"; enabled: songModel ? (songModel.currentPage < songModel.totalPages - 1) : false; onClicked: { if (songModel) songModel.goToPage(songModel.totalPages - 1) } }
                }
            }
        }
    }

    // ── 分页按钮组件 ──
    component PageNavButton: Rectangle {
        id: btn
        property bool enabled: true
        property alias text: btnText.text
        signal clicked()

        width: 30; height: 26; radius: 5
        color: {
            if (!enabled) return "#1A2436"
            if (btnMouse.containsMouse) return "#2E3D55"
            return "#1E2D44"
        }
        border.color: enabled ? "#3D4A5C" : "#26364A"
        border.width: 1

        Text {
            id: btnText
            anchors.centerIn: parent
            color: enabled ? "#C9D2E3" : "#4B5563"
            font.pixelSize: 11; font.bold: true
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: { if (enabled) btn.clicked() }
        }
    }

    // ── 无交互的列间距占位（与数据行 Item{4} 完全一致） ──
    component ColumnSpacer: Item {
        Layout.preferredWidth: 4
        Layout.fillHeight: true
    }

    // ── 列拖动手柄组件 ──
    component ColumnDragHandle: Item {
        id: handle
        required property string column

        Layout.preferredWidth: 4
        Layout.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: 2; height: parent.height
            color: mouse.containsMouse || root.draggingCol === column ? "#FFB300" : "transparent"
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SplitHCursor

            onPressed: {
                root.draggingCol = column
                root.dragStartX = mouse.x
                root.dragStartWidth = root[column]
            }
            onPositionChanged: {
                if (root.draggingCol === column) {
                    var delta = mouse.x - root.dragStartX
                    var newWidth = Math.max(root.minColWidth, root.dragStartWidth + delta)
                    root[column] = newWidth
                }
            }
            onReleased: {
                root.draggingCol = ""
            }
        }
    }
}