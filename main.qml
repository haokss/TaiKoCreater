import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "ui/pages"
import "ui/panels"
import "ui/views"

ApplicationWindow {
    id: appWindow
    visible: true
    width: 1480
    height: 900
    title: "歌曲排序工具"
    flags: Qt.FramelessWindowHint | Qt.Window

    readonly property color bgDark:         "#0D1117"
    readonly property color cardBg:         "#162132"
    readonly property color panelBg:        "#111827"
    readonly property color borderColor:    "#273247"
    readonly property color textPrimary:    "#E6E8F0"
    readonly property color textSecondary:  "#8FA6C6"
    readonly property color accentBlue:     "#4A90D9"
    readonly property color successGreen:   "#4CAF50"
    readonly property color warningOrange:  "#FF9800"

    readonly property color titleBarBg:     "#1E1E2E"
    readonly property color titleBarHover:  "#2E2E3E"
    readonly property color closeBtnHover:  "#E81123"
    readonly property color closeBtnPress:  "#BF0F1A"

    property bool showDebugPanel: false

    font.family: "Yu Gothic UI, Microsoft YaHei UI, Meiryo, Noto Sans CJK SC, sans-serif"

    // ── 窗口背景 ──
    background: Rectangle {
        color: bgDark
    }

    // ── 谱面详情窗口 ──
    SongDetail {
        id: detailWindow
        onVisibleChanged: {
            if (!visible) {
                detailWindow.realTitle = ""
                detailWindow.realBpm = 0
                detailWindow.realGenre = ""
                detailWindow.realCourses = []
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ═══════════════════════════════════════════
        // 自定义标题栏
        // ═══════════════════════════════════════════
        Rectangle {
            id: titleBar
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: titleBarBg
            radius: 0

            // ── 窗口控制按钮（右侧，z 值最高确保优先接收事件） ──
            Rectangle {
                id: closeBtn
                width: 46
                height: parent.height
                anchors.right: parent.right
                anchors.top: parent.top
                z: 10
                color: closeBtnArea.containsMouse
                       ? (closeBtnArea.pressed ? closeBtnPress : closeBtnHover)
                       : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: closeBtnArea.containsMouse ? "#FFFFFF" : "#CCCCCC"
                    font.pointSize: 11
                }

                MouseArea {
                    id: closeBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.quit()
                }
            }

            Rectangle {
                id: maxBtn
                width: 46
                height: parent.height
                anchors.right: closeBtn.left
                anchors.top: parent.top
                z: 10
                color: maxBtnArea.containsMouse ? titleBarHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: appWindow.visibility === Window.Maximized ? "❐" : "□"
                    color: "#CCCCCC"
                    font.pointSize: 10
                }

                MouseArea {
                    id: maxBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toggleMaximize()
                }
            }

            Rectangle {
                id: minBtn
                width: 46
                height: parent.height
                anchors.right: maxBtn.left
                anchors.top: parent.top
                z: 10
                color: minBtnArea.containsMouse ? titleBarHover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "─"
                    color: "#CCCCCC"
                    font.pointSize: 12
                    font.bold: true
                }

                MouseArea {
                    id: minBtnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appWindow.showMinimized()
                }
            }

            // ── 标题文字 ──
            Text {
                text: "🎵 歌曲排序工具"
                color: "#FFFFFF"
                font.bold: true
                font.pointSize: 11
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                z: 1
            }

            // ── 窗口拖动区域（填充按钮左侧全部空间） ──
            MouseArea {
                id: titleDragArea
                anchors.left: parent.left
                anchors.right: minBtn.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                z: 1
                property real pressX: 0
                property real pressY: 0
                onPressed: {
                    pressX = mouse.x
                    pressY = mouse.y
                }
                onPositionChanged: {
                    appWindow.x += mouse.x - pressX
                    appWindow.y += mouse.y - pressY
                }
                onDoubleClicked: toggleMaximize()
            }
        }

        // ═══════════════════════════════════════════
        // 主内容区
        // ═══════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 12
            spacing: 6

            // ── Tab 栏 + 调试日志按钮 ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    spacing: 4

                    background: Rectangle {
                        color: "transparent"
                    }

                    TabButton {
                        id: filterTab
                        text: "筛选排序"
                        font.pointSize: 13; width: 130
                        font.bold: filterTab.checked
                        contentItem: Text {
                            text: parent.text
                            font.pointSize: 13
                            font.bold: filterTab.checked
                            color: filterTab.checked ? "#E6E8F0" : "#5B657A"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: "transparent"
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: filterTab.checked ? parent.width * 0.7 : 0
                                height: 3
                                color: "#FFB300"
                                radius: 1.5
                                visible: width > 0
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    TabButton {
                        id: flexTab
                        text: "弹性布局"
                        font.pointSize: 13; width: 130
                        font.bold: flexTab.checked
                        contentItem: Text {
                            text: parent.text
                            font.pointSize: 13
                            font.bold: flexTab.checked
                            color: flexTab.checked ? "#E6E8F0" : "#5B657A"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: "transparent"
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: flexTab.checked ? parent.width * 0.7 : 0
                                height: 3
                                color: "#FFB300"
                                radius: 1.5
                                visible: width > 0
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    TabButton {
                        id: aiTab
                        text: "AI 作谱"
                        font.pointSize: 13; width: 130
                        font.bold: aiTab.checked
                        contentItem: Text {
                            text: parent.text
                            font.pointSize: 13
                            font.bold: aiTab.checked
                            color: aiTab.checked ? "#E6E8F0" : "#5B657A"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: "transparent"
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: aiTab.checked ? parent.width * 0.7 : 0
                                height: 3
                                color: "#FFB300"
                                radius: 1.5
                                visible: width > 0
                                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                }

                Button {
                    text: showDebugPanel ? "隐藏日志" : "调试日志"
                    onClicked: showDebugPanel = !showDebugPanel
                }
            }

            // ── Tab 内容区 ──
            StackLayout {
                id: stackLayout
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabBar.currentIndex

                FilterSortPage {
                    id: filterSortPage

                    onSongClicked: function(title, bpm, genre, courses, index) {
                        loadSongDetail(title, bpm, genre, courses, index)
                    }
                }

                FlexLayoutPage {
                    id: flexLayoutPage
                }

                AIGeneratePage {
                    id: aiGeneratePage
                }
            }

            // ── 调试日志面板（全局常驻） ──
            DebugPanel {
                id: debugPanel
                Layout.fillWidth: true
                Layout.preferredHeight: showDebugPanel ? 150 : 0
                visible: showDebugPanel
            }
        }
    }

    // ── Toast 置顶消息弹框（浮层，独立于布局） ──
    ToastNotification {
        id: toastNotification
    }

    // ── ToastManager 连接 ──
    Connections {
        target: toastManager
        onToastRequested: toastNotification.show()
    }

    function toggleMaximize() {
        if (appWindow.visibility === Window.Maximized)
            appWindow.showNormal()
        else
            appWindow.showMaximized()
    }

    function loadPath(path) {
        if (!path || !songModel) return
        toastManager.info("正在加载歌曲数据...")
        songModel.setRootPathAsync(path)
    }

    function loadSongDetail(title, bpm, genre, courses, index) {
        var courseList = courses || []
        var allCourseData = []
        for (var i = 0; i < courseList.length; i++) {
            var courseName = courseList[i].course
            var chartData = songModel.getChartData(index, courseName)
            if (chartData && chartData.measureLines && chartData.measureLines.length > 0) {
                allCourseData.push({
                    course: chartData.course || courseName,
                    level: chartData.level || 0,
                    notes: chartData.measureLines
                })
            }
        }
        detailWindow.realTitle = title
        detailWindow.realBpm = bpm
        detailWindow.realGenre = genre
        detailWindow.realCourses = allCourseData
        detailWindow.selectedCourseIndex = 0
        detailWindow.show()
        detailWindow.raise()
    }
}