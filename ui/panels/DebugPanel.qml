import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    color: "#162132"
    radius: 8
    clip: true
    border.color: "#273247"
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
                    color: "#1D2C44"
                    radius: 4
                    border.color: "#273247"
                }
                contentItem: Text {
                    text: parent.text
                    color: "#8FA6C6"
                    font.pointSize: 9
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1D2C44"
            radius: 4
            border.color: "#273247"
            ScrollView {
                anchors.fill: parent
                anchors.margins: 2
                clip: true
                ListView {
                    id: logView
                    model: logger ? logger.logs : []
                    delegate: Text {
                        text: modelData
                        color: "#C9D2E3"
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
