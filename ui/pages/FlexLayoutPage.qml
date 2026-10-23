import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../panels"

// 弹性布局骨架 Tab 页 — 五功能面板 + 缩放 + 水平拖动
Item {
    id: root
    readonly property int snapThreshold: 20
    property real zoomLevel: 1.0     // 共享缩放级别 (0.5 ~ 5.0)
    property real scrollX: 0          // 共享水平偏移

    function adjustZoom(delta, mouseXRatio) {
        var viewW = timelinePanel.width - 16;  // approximate content width
        var oldCenterX = (scrollX + mouseXRatio * viewW) / zoomLevel;
        zoomLevel = Math.max(0.5, Math.min(5.0, zoomLevel + delta));
        // 保持鼠标位置为缩放中心
        scrollX = Math.max(0, Math.min(viewW * (zoomLevel - 1), oldCenterX * zoomLevel - mouseXRatio * viewW));
    }

    function adjustPan(deltaX) {
        var viewW = timelinePanel.width - 16;
        scrollX = Math.max(0, Math.min(viewW * (zoomLevel - 1), scrollX + deltaX));
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 0

        // 拖动容器
        Item {
            id: dockArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

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
                    editorPanel.chartData = data;
                }
            }

            // 3. 时间轴面板（编辑器上方）
            TimelinePanel {
                id: timelinePanel
                x: 180
                y: 180
                dockArea: dockArea
                zoomLevel: root.zoomLevel
                scrollX: root.scrollX
                onDragReleased: snapPanel(2)
                onZoomRequested: function (delta, mouseXRatio) {
                    root.adjustZoom(delta, mouseXRatio);
                }
                onPanRequested: function (dx) {
                    root.adjustPan(dx);
                }
            }

            // 4. 中间编辑区面板（中间）
            EditorPanel {
                id: editorPanel
                x: 180
                y: 260
                dockArea: dockArea
                chartData: ({})
                onDragReleased: snapPanel(3)
            }

            // 5. 波形图面板（最下方）
            WaveformPanel {
                id: waveformPanel
                x: 180
                y: 620
                dockArea: dockArea
                zoomLevel: root.zoomLevel
                scrollX: root.scrollX
                onDragReleased: snapPanel(4)
                onZoomRequested: function (delta, mouseXRatio) {
                    root.adjustZoom(delta, mouseXRatio);
                }
                onPanRequested: function (dx) {
                    root.adjustPan(dx);
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
        }
    }

    // ====== 吸附逻辑 ======
    function panelByIdx(i) {
        switch (i) {
        case 0:
            return infoPanel;
        case 1:
            return playPanel;
        case 2:
            return timelinePanel;
        case 3:
            return editorPanel;
        case 4:
            return waveformPanel;
        case 5:
            return toolPanel;
        default:
            return null;
        }
    }

    function rectsOverlap(a, b) {
        return !(a.x + a.width <= b.x || b.x + b.width <= a.x || a.y + a.height <= b.y || b.y + b.height <= a.y);
    }

    function overlapArea(a, b) {
        var ox = Math.max(0, Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x));
        var oy = Math.max(0, Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y));
        return ox * oy;
    }

    function snapPanel(idx) {
        var p = panelByIdx(idx);
        if (!p)
            return;
        var bestX = p.x, bestY = p.y, bestDist = snapThreshold;
        var candidates = [
            {
                x: 0,
                y: p.y
            },
            {
                x: Math.max(0, dockArea.width - p.width),
                y: p.y
            },
            {
                x: p.x,
                y: 0
            },
            {
                x: p.x,
                y: Math.max(0, dockArea.height - p.height)
            }
        ];
        for (var i = 0; i < 6; i++) {
            if (i === idx)
                continue;
            var q = panelByIdx(i);
            if (!q)
                continue;
            candidates.push({
                x: q.x,
                y: p.y
            });
            candidates.push({
                x: q.x + q.width - p.width,
                y: p.y
            });
            candidates.push({
                x: q.x + q.width,
                y: p.y
            });
            candidates.push({
                x: q.x - p.width,
                y: p.y
            });
            candidates.push({
                x: p.x,
                y: q.y
            });
            candidates.push({
                x: p.x,
                y: q.y + q.height - p.height
            });
            candidates.push({
                x: p.x,
                y: q.y + q.height
            });
            candidates.push({
                x: p.x,
                y: q.y - p.height
            });
            candidates.push({
                x: q.x,
                y: q.y
            });
            candidates.push({
                x: q.x + q.width - p.width,
                y: q.y
            });
            candidates.push({
                x: q.x,
                y: q.y + q.height - p.height
            });
            candidates.push({
                x: q.x + q.width - p.width,
                y: q.y + q.height - p.height
            });
        }
        for (var c = 0; c < candidates.length; c++) {
            var cand = candidates[c];
            if (cand.x < 0 || cand.y < 0)
                continue;
            if (cand.x > dockArea.width - p.width)
                continue;
            if (cand.y > dockArea.height - p.height)
                continue;
            var dx = cand.x - p.x, dy = cand.y - p.y;
            var dist = Math.sqrt(dx * dx + dy * dy);
            if (dist < bestDist) {
                bestDist = dist;
                bestX = cand.x;
                bestY = cand.y;
            }
        }
        p.x = bestX;
        p.y = bestY;
        resolveCollision(idx);
    }

    // ── 碰撞解决：把 p 和其他面板推开，直到无重叠 ──
    function resolveCollision(idx) {
        var p = panelByIdx(idx);
        if (!p)
            return;
        var maxIter = 10;
        for (var iter = 0; iter < maxIter; iter++) {
            var overlapFound = false;
            for (var i = 0; i < 6; i++) {
                if (i === idx)
                    continue;
                var q = panelByIdx(i);
                if (!q)
                    continue;
                if (!rectsOverlap(p, q))
                    continue;
                overlapFound = true;

                // 计算四个方向的分离距离
                var leftDist = (p.x + p.width) - q.x;
                var rightDist = (q.x + q.width) - p.x;
                var topDist = (p.y + p.height) - q.y;
                var bottomDist = (q.y + q.height) - p.y;

                // 选择最小分离距离的方向
                var minDist = Math.min(leftDist, rightDist, topDist, bottomDist);
                var newX = p.x, newY = p.y;

                if (minDist === leftDist) {
                    newX = q.x - p.width;
                } else if (minDist === rightDist) {
                    newX = q.x + q.width;
                } else if (minDist === topDist) {
                    newY = q.y - p.height;
                } else {
                    newY = q.y + q.height;
                }

                // 边界约束
                newX = Math.max(0, Math.min(newX, dockArea.width - p.width));
                newY = Math.max(0, Math.min(newY, dockArea.height - p.height));

                p.x = newX;
                p.y = newY;  // 一次只处理一个重叠，下次迭代继续
                break;
            }
            if (!overlapFound)
                break;
        }
    }

    function resetPositions() {

        // 歌曲信息
        infoPanel.x = 8;
        infoPanel.y = 8;

        // 播放控制
        playPanel.x = 580;
        playPanel.y = 8;

        // 左侧工具栏
        toolPanel.x = 8;
        toolPanel.y = 180;

        // 时间轴
        timelinePanel.x = 180;
        timelinePanel.y = 180;

        // 主编辑区
        editorPanel.x = 180;
        editorPanel.y = 260;

        // 波形
        waveformPanel.x = 180;
        waveformPanel.y = 620;

        scrollX = 0;
        zoomLevel = 1.0;
    }
}
