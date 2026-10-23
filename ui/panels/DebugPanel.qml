import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    color: "#FFFFFF"
    radius: 8
    clip: true
    border.color: "#E0E0E0"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        RowLayout {
            spacing: 8
            Text {
                text: "调试日志"
                color: '#000000'
                font.bold: true
                font.pointSize: 11
            }
            Item {
                Layout.fillWidth: true
            }
            Button {
                text: "清空日志"
                onClicked: if (logger)
                    logger.clear()
                background: Rectangle {
                    color: "#F0F0F0"
                    radius: 4
                    border.color: "#DDD"
                }
                contentItem: Text {
                    text: parent.text
                    color: "#666"
                    font.pointSize: 9
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#F5F5F5"
            radius: 4
            border.color: "#E0E0E0"
            ScrollView {
                anchors.fill: parent
                anchors.margins: 2
                clip: true
                ListView {
                    id: logView
                    model: logger ? logger.logs : []
                    delegate: Text {
                        text: modelData
                        color: "#333"
                        font.pointSize: 8
                        font.family: "Consolas, Courier New, monospace"
                        wrapMode: Text.WordWrap
                        width: parent ? parent.width : 800
                        padding: 2
                    }
                }
            }
        }
    }
}
