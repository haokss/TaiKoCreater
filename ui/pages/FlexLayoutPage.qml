import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../panels"

// ═══════════════════════════════════════════════════════════════════
// 编曲台（原「弹性布局」）
//
// 六个可拖拽面板：歌曲信息 / 播放控制 / 时间轴 / 编辑区 / 波形 / 音符工具
//   · 顶部工具栏：缩放控制、整理布局、重置视图
//   · 面板拖动后按 20px 阈值吸附，并做 AABB 碰撞推挤，保证不重叠
//   · 首次进入按容器尺寸自动排布，窗口缩放时跟随（用户手动拖过后不再自动）
// ═══════════════════════════════════════════════════════════════════
Item {
    id: root

    readonly property int snapThreshold: 20
    readonly property int gap: 8
    readonly property int sideX: 596 // 左列宽度(580) + 间距
    property real zoomLevel: 1.0     // 共享缩放级别 (0.5 ~ 5.0)
    property real scrollX: 0         // 共享水平偏移
    property bool userMoved: false   // 用户手动拖过面板后，不再自动重排

    readonly property color barColor: "#0F1826"
    readonly property color bgColor: "#0B1220"
    readonly property color gridColor: "#141D2C"
    readonly property color lineColor: "#1E2B40"
    readonly property color textPrimary: "#C9D2E3"
    readonly property color textSecondary: "#5B657A"

    // ── 缩放 / 平移（与面板共享）──
    function adjustZoom(delta, mouseXRatio) {
        var viewW = Math.max(1, dockArea.width - 16)
        var oldCenterX = (scrollX + mouseXRatio * viewW) / zoomLevel
        zoomLevel = Math.max(0.5, Math.min(5.0, zoomLevel + delta))
        scrollX = Math.max(0, Math.min(viewW * (zoomLevel - 1), oldCenterX * zoomLevel - mouseXRatio * viewW))
    }

    function adjustPan(deltaX) {
        var viewW = Math.max(1, dockArea.width - 16)
        scrollX = Math.max(0, Math.min(viewW * (zoomLevel - 1), scrollX + deltaX))
    }

    // ── 自动排布：按容器尺寸算，不再写死像素 ──
    function arrange() {
        var W = dockArea.width
        var H = dockArea.height
        if (W < 200 || H < 200)
            return

        infoPanel.x = gap
        infoPanel.y = gap

        toolPanel.x = gap
        toolPanel.y = infoPanel.y + infoPanel.height + gap
        toolPanel.height = Math.max(180, H - toolPanel.y - gap)

        var sideW = Math.max(420, W - sideX - gap)
        playPanel.x = sideX
        playPanel.y = gap
        playPanel.width = sideW

        // 右列：播放(定高) / 时间轴(定高) / 编辑区(保持自身高度)
        var flowTop = gap + playPanel.height + gap + timelinePanel.height + gap

        timelinePanel.x = sideX
        timelinePanel.y = gap + playPanel.height + gap
        timelinePanel.width = sideW

        editorPanel.x = sideX
        editorPanel.y = flowTop
        editorPanel.width = sideW

        // 波形放到左列底部（工具面板下方），利用那块空白，右列不再被挤压
        waveformPanel.x = gap
        waveformPanel.y = toolPanel.y + toolPanel.height + gap
        waveformPanel.width = infoPanel.width
        waveformPanel.height = Math.max(110, H - waveformPanel.y - gap)

        userMoved = false
        scrollX = 0
        zoomLevel = 1.0
    }

    // 窗口尺寸变化：没手动拖过就跟着重排，拖过则只做边界收敛
    function onDockResized() {
        if (!userMoved)
            arrange()
        else
            clampAll()
    }

    function clampAll() {
        for (var i = 0; i < 6; i++) {
            var p = panelByIdx(i)
            if (!p)
                continue
            p.x = Math.max(0, Math.min(p.x, Math.max(0, dockArea.width - p.width)))
            p.y = Math.max(0, Math.min(p.y, Math.max(0, dockArea.height - p.height)))
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ═════════════════ 工具栏 ═════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: root.barColor

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.lineColor
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 10

                Rectangle {
                    implicitWidth: 6
                    implicitHeight: 18
                    radius: 3
                    color: "#4DA3FF"
                }

                Text {
                    text: qsTr("编曲台")
                    color: root.textPrimary
                    font.pointSize: 12
                    font.bold: true
                }

                Text {
                    text: qsTr("拖动面板标题栏移动 · 滚轮缩放时间轴")
                    color: root.textSecondary
                    font.pointSize: 9
                }

                Item { Layout.fillWidth: true }

                // 缩放控制
                Row {
                    spacing: 4

                    Text {
                        text: qsTr("缩放")
                        color: root.textSecondary
                        font.pointSize: 9
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 5
                        color: minusArea.containsMouse ? "#1B2A42" : "#141F31"
                        border.width: 1
                        border.color: root.lineColor

                        Text {
                            anchors.centerIn: parent
                            text: "－"
                            color: root.textPrimary
                            font.pointSize: 10
                        }

                        MouseArea {
                            id: minusArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.adjustZoom(-0.1, 0.5)
                        }
                    }

                    Text {
                        width: 46
                        text: Math.round(root.zoomLevel * 100) + "%"
                        color: root.textPrimary
                        font.pointSize: 10
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 5
                        color: plusArea.containsMouse ? "#1B2A42" : "#141F31"
                        border.width: 1
                        border.color: root.lineColor

                        Text {
                            anchors.centerIn: parent
                            text: "＋"
                            color: root.textPrimary
                            font.pointSize: 10
                        }

                        MouseArea {
                            id: plusArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.adjustZoom(0.1, 0.5)
                        }
                    }
                }

                // 操作按钮
                Rectangle {
                    implicitWidth: arrangeLabel.implicitWidth + 24
                    implicitHeight: 26
                    radius: 5
                    color: arrangeArea.containsMouse ? "#1B2A42" : "transparent"
                    border.width: 1
                    border.color: root.lineColor

                    Text {
                        id: arrangeLabel
                        anchors.centerIn: parent
                        text: qsTr("整理布局")
                        color: root.textPrimary
                        font.pointSize: 9
                    }

                    MouseArea {
                        id: arrangeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.arrange()
                    }
                }

                Rectangle {
                    implicitWidth: resetLabel.implicitWidth + 24
                    implicitHeight: 26
                    radius: 5
                    color: resetArea.containsMouse ? "#1B2A42" : "transparent"
                    border.width: 1
                    border.color: root.lineColor

                    Text {
                        id: resetLabel
                        anchors.centerIn: parent
                        text: qsTr("重置视图")
                        color: root.textPrimary
                        font.pointSize: 9
                    }

                    MouseArea {
                        id: resetArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.scrollX = 0
                            root.zoomLevel = 1.0
                        }
                    }
                }
            }
        }

        // ═════════════════ 面板容器 ═════════════════
        Item {
            id: dockArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // 网格底
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = root.gridColor
                    ctx.lineWidth = 1
                    for (var x = 0; x < width; x += 24) {
                        ctx.beginPath()
                        ctx.moveTo(x + 0.5, 0)
                        ctx.lineTo(x + 0.5, height)
                        ctx.stroke()
                    }
                    for (var y = 0; y < height; y += 24) {
                        ctx.beginPath()
                        ctx.moveTo(0, y + 0.5)
                        ctx.lineTo(width, y + 0.5)
                        ctx.stroke()
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Component.onCompleted: requestPaint()
            }

            // 1. 歌曲信息面板（左上）
            SongInfoPanel {
                id: infoPanel
                x: 8
                y: 8
                dockArea: dockArea
                onDragReleased: snapPanel(0)
            }

            // 2. 播放控制面板（右上）
            PlaybackControlPanel {
                id: playPanel
                x: 580
                y: 8
                dockArea: dockArea
                onDragReleased: snapPanel(1)
                onTjaLoaded: function (data) {
                    editorPanel.chartData = data
                }
            }

            // 3. 时间轴面板
            TimelinePanel {
                id: timelinePanel
                x: 180
                y: 180
                dockArea: dockArea
                zoomLevel: root.zoomLevel
                scrollX: root.scrollX
                onDragReleased: snapPanel(2)
                onZoomRequested: function (delta, mouseXRatio) {
                    root.adjustZoom(delta, mouseXRatio)
                }
                onPanRequested: function (dx) {
                    root.adjustPan(dx)
                }
            }

            // 4. 中间编辑区面板
            EditorPanel {
                id: editorPanel
                x: 180
                y: 260
                dockArea: dockArea
                chartData: ({})
                onDragReleased: snapPanel(3)
            }

            // 5. 波形图面板
            WaveformPanel {
                id: waveformPanel
                x: 180
                y: 620
                dockArea: dockArea
                zoomLevel: root.zoomLevel
                scrollX: root.scrollX
                onDragReleased: snapPanel(4)
                onZoomRequested: function (delta, mouseXRatio) {
                    root.adjustZoom(delta, mouseXRatio)
                }
                onPanRequested: function (dx) {
                    root.adjustPan(dx)
                }
            }

            // 6. 音符工具面板
            ToolPanel {
                id: toolPanel
                x: 8
                y: 180
                dockArea: dockArea
                onDragReleased: snapPanel(5)
            }

            Component.onCompleted: Qt.callLater(root.arrange)
            onWidthChanged: root.onDockResized()
            onHeightChanged: root.onDockResized()
        }
    }

    // ====== 吸附逻辑 ======
    function panelByIdx(i) {
        switch (i) {
        case 0:
            return infoPanel
        case 1:
            return playPanel
        case 2:
            return timelinePanel
        case 3:
            return editorPanel
        case 4:
            return waveformPanel
        case 5:
            return toolPanel
        default:
            return null
        }
    }

    function rectsOverlap(a, b) {
        return !(a.x + a.width <= b.x || b.x + b.width <= a.x || a.y + a.height <= b.y || b.y + b.height <= a.y)
    }

    function overlapArea(a, b) {
        var ox = Math.max(0, Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x))
        var oy = Math.max(0, Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y))
        return ox * oy
    }

    function snapPanel(idx) {
        userMoved = true
        var p = panelByIdx(idx)
        if (!p)
            return
        var bestX = p.x, bestY = p.y, bestDist = snapThreshold
        var candidates = [
            { x: 0, y: p.y },
            { x: Math.max(0, dockArea.width - p.width), y: p.y },
            { x: p.x, y: 0 },
            { x: p.x, y: Math.max(0, dockArea.height - p.height) }
        ]
        for (var i = 0; i < 6; i++) {
            if (i === idx)
                continue
            var q = panelByIdx(i)
            if (!q)
                continue
            candidates.push({ x: q.x, y: p.y })
            candidates.push({ x: q.x + q.width - p.width, y: p.y })
            candidates.push({ x: q.x + q.width, y: p.y })
            candidates.push({ x: q.x - p.width, y: p.y })
            candidates.push({ x: p.x, y: q.y })
            candidates.push({ x: p.x, y: q.y + q.height - p.height })
            candidates.push({ x: p.x, y: q.y + q.height })
            candidates.push({ x: p.x, y: q.y - p.height })
            candidates.push({ x: q.x, y: q.y })
            candidates.push({ x: q.x + q.width - p.width, y: q.y })
            candidates.push({ x: q.x, y: q.y + q.height - p.height })
            candidates.push({ x: q.x + q.width - p.width, y: q.y + q.height - p.height })
        }
        for (var c = 0; c < candidates.length; c++) {
            var cand = candidates[c]
            if (cand.x < 0 || cand.y < 0)
                continue
            if (cand.x > dockArea.width - p.width)
                continue
            if (cand.y > dockArea.height - p.height)
                continue
            var dx = cand.x - p.x, dy = cand.y - p.y
            var dist = Math.sqrt(dx * dx + dy * dy)
            if (dist < bestDist) {
                bestDist = dist
                bestX = cand.x
                bestY = cand.y
            }
        }
        p.x = bestX
        p.y = bestY
        resolveCollision(idx)
    }

    // ── 碰撞解决：把 p 和其他面板推开，直到无重叠 ──
    function resolveCollision(idx) {
        var p = panelByIdx(idx)
        if (!p)
            return
        var maxIter = 10
        for (var iter = 0; iter < maxIter; iter++) {
            var overlapFound = false
            for (var i = 0; i < 6; i++) {
                if (i === idx)
                    continue
                var q = panelByIdx(i)
                if (!q)
                    continue
                if (!rectsOverlap(p, q))
                    continue
                overlapFound = true

                var leftDist = (p.x + p.width) - q.x
                var rightDist = (q.x + q.width) - p.x
                var topDist = (p.y + p.height) - q.y
                var bottomDist = (q.y + q.height) - p.y

                var minDist = Math.min(leftDist, rightDist, topDist, bottomDist)
                var newX = p.x, newY = p.y

                if (minDist === leftDist) {
                    newX = q.x - p.width
                } else if (minDist === rightDist) {
                    newX = q.x + q.width
                } else if (minDist === topDist) {
                    newY = q.y - p.height
                } else {
                    newY = q.y + q.height
                }

                newX = Math.max(0, Math.min(newX, dockArea.width - p.width))
                newY = Math.max(0, Math.min(newY, dockArea.height - p.height))

                p.x = newX
                p.y = newY
                break
            }
            if (!overlapFound)
                break
        }
    }

    function resetPositions() {
        arrange()
    }
}
