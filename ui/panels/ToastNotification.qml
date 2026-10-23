import QtQuick 2.15
import QtQuick.Controls 2.15

/// 置顶消息提示弹框
/// 使用方式:
///   Connections {
///       target: toastManager
///       onToastRequested: toastNotification.show()
///   }
Rectangle {
    id: root

    // ── 公开属性 ──
    property int toastType: toastManager ? toastManager.type : 0
    property string toastMessage: toastManager ? toastManager.message : ""
    property int toastDuration: toastManager ? toastManager.durationMs : 3000

    // 类型 → 颜色映射
    readonly property var typeColors: ({
        0: "#4A90D9",   // Info    蓝色
        1: "#4CAF50",   // Success 绿色
        2: "#FF9800",   // Warning 橙色
        3: "#E60012"    // Error   红色
    })

    readonly property var typeIcons: ({
        0: "ℹ",
        1: "✓",
        2: "⚠",
        3: "✗"
    })

    // 默认隐藏
    visible: false
    opacity: 0
    z: 9999 // 置顶

    width: Math.min(500, parent ? parent.width * 0.75 : 400)
    height: toastContent.implicitHeight + 32
    radius: 10

    // 定位在窗口右上角
    anchors {
        top: parent ? parent.top : undefined
        topMargin: 20
        right: parent ? parent.right : undefined
        rightMargin: 20
    }

    // 阴影层（偏移 3px，模拟阴影效果）
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        radius: parent.radius
        color: Qt.rgba(0, 0, 0, 0.08)
        z: -1
    }

    color: "#FFFFFF"
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, 0.1)

    // ── 进入/退出动画 ──
    Behavior on opacity {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    // ── 内容行 ──
    Row {
        id: toastContent
        anchors {
            left: parent.left
            leftMargin: 16
            right: parent.right
            rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
        spacing: 12

        // 左侧类型色条
        Rectangle {
            width: 4
            height: 40
            radius: 2
            color: typeColors[toastType] || typeColors[0]
        }

        // 图标
        Rectangle {
            width: 32
            height: 32
            radius: 16
            color: typeColors[toastType] || typeColors[0]
            Text {
                anchors.centerIn: parent
                text: typeIcons[toastType] || typeIcons[0]
                color: "#FFFFFF"
                font.pointSize: 14
                font.bold: true
            }
        }

        // 消息文本
        Text {
            id: messageText
            text: toastMessage
            color: "#222222"
            font.pointSize: 13
            font.family: "Yu Gothic UI, Microsoft YaHei UI, Meiryo, Noto Sans CJK SC, sans-serif"
            wrapMode: Text.WordWrap
            width: root.width - 128
            topPadding: 8
            bottomPadding: 8
        }
    }

    // ── 自动隐藏计时器（两段式：先淡出，再隐藏） ──
    Timer {
        id: hideTimer
        interval: toastDuration
        running: false
        repeat: false
        onTriggered: {
            if (opacity > 0) {
                // 第一次触发：开始淡出动画
                opacity = 0
                interval = 260
                restart()
            } else {
                // 第二次触发：完全隐藏
                visible = false
            }
        }
    }

    // ── 显示 / 隐藏 ──
    function show() {
        // 刷新属性
        toastType = toastManager ? toastManager.type : 0
        toastMessage = toastManager ? toastManager.message : ""
        toastDuration = toastManager ? toastManager.durationMs : 3000

        if (!toastMessage) return

        visible = true
        opacity = 1.0
        hideTimer.interval = toastDuration
        hideTimer.restart()
    }

    function hide() {
        hideTimer.stop()
        opacity = 0
        visible = false
    }
}