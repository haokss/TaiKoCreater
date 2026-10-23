import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    color: "#111827"
    radius: 12

    border.color: "#273247"
    border.width: 1

    implicitWidth: 280
    implicitHeight: 190

    property int selectedMinLevel: 0
    property int selectedMaxLevel: 0

    property string selectedGenre: "全部"
    property string selectedCourse: "全部"

    property string selectedSortField: "title"
    property bool selectedSortAsc: true

    signal exportCsv()
    signal exportJson()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        //--------------------------------------------------
        // 标题
        //--------------------------------------------------

        RowLayout {

            Rectangle {
                width: 3
                height: 16
                radius: 2
                color: "#FF4DA6"
            }

            Label {
                text: "统计信息"
                color: "white"
                font.bold: true
                font.pixelSize: 16
            }
        }

        //--------------------------------------------------
        // 两个统计卡片
        //--------------------------------------------------

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {

                Layout.fillWidth: true
                Layout.preferredHeight: 58

                radius: 8

                color: "#162132"
                border.color: "#26364A"

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Label {
                        text: "歌曲总数"
                        color: "#C9D2E3"
                        font.pixelSize: 11
                    }

                    Label {
                        text: songModel ? songModel.totalCount : songModel.count

                        color: "#FF4DA6"

                        font.pixelSize: 22
                        font.bold: true

                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Rectangle {

                Layout.fillWidth: true
                Layout.preferredHeight: 58

                radius: 8

                color: "#162132"
                border.color: "#26364A"

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Label {
                        text: "当前结果"
                        color: "#C9D2E3"
                        font.pixelSize: 11
                    }

                    Label {
                        text: songModel ? songModel.count : 0

                        color: "#4DA3FF"

                        font.pixelSize: 22
                        font.bold: true

                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        //--------------------------------------------------
        // 当前筛选条件
        //--------------------------------------------------

        Rectangle {

            Layout.fillWidth: true
            Layout.preferredHeight: 70

            radius: 8

            color: "#162132"
            border.color: "#26364A"

            ColumnLayout {

                anchors.fill: parent
                anchors.margins: 10

                spacing: 4

                Label {
                    text: "当前筛选条件"
                    color: "white"
                    font.pixelSize: 13
                    font.bold: true
                }

                Label {
                    text: "• 最低: " + (selectedMinLevel > 0 ? selectedMinLevel : "不限")
                        + "     • 最高: " + (selectedMaxLevel > 0 ? selectedMaxLevel : "不限")
                    color: "#D7E1F2"
                    font.pixelSize: 11
                }

                Label {
                    text: "• 类型: " + selectedGenre
                          + "  |  难度: " + selectedCourse
                    color: "#D7E1F2"
                    font.pixelSize: 11
                }

                Label {
                    text: "• 排序: " + selectedSortField
                          + (selectedSortAsc ? " ↑" : " ↓")
                    color: "#D7E1F2"
                    font.pixelSize: 11
                }
            }
        }

        //--------------------------------------------------
        // 导出按钮
        //--------------------------------------------------

        RowLayout {

            Layout.fillWidth: true
            spacing: 6

            Button {

                Layout.fillWidth: true
                text: "导出 CSV"

                background: Rectangle {

                    radius: 6

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#2F9E67"
                        }
                        GradientStop {
                            position: 1
                            color: "#237D52"
                        }
                    }

                    border.color: "#43C985"
                }

                contentItem: Text {

                    text: parent.text

                    color: "white"
                    font.bold: true
                    font.pixelSize: 12

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: root.exportCsv()
            }

            Button {

                Layout.fillWidth: true
                text: "导出 JSON"

                background: Rectangle {

                    radius: 6

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "#3D6FFF"
                        }
                        GradientStop {
                            position: 1
                            color: "#3058D5"
                        }
                    }

                    border.color: "#5D89FF"
                }

                contentItem: Text {

                    text: parent.text

                    color: "white"
                    font.bold: true
                    font.pixelSize: 12

                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: root.exportJson()
            }
        }

        //--------------------------------------------------
        // 状态信息
        //--------------------------------------------------

        Label {

            id: statusLabel

            Layout.fillWidth: true

            color: "#8FA6C6"

            font.pixelSize: 11

            wrapMode: Text.WordWrap
        }
    }
}