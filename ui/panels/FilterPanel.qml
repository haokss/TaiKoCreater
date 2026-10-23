import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: panel

    color: "#111827"
    radius: 12

    border.color: "#273247"
    border.width: 1

    property int selectedMinLevel: 0
    property int selectedMaxLevel: 0

    property string selectedGenre: "全部"
    property string selectedCourse: "全部"

    property string selectedSortField: "title"
    property bool selectedSortAsc: true

    signal statusMessage(string msg)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        //------------------------------------
        // 标题
        //------------------------------------

        RowLayout {

            Rectangle {
                width: 3
                height: 16
                radius: 2
                color: "#FF4DA6"
            }

            Label {
                text: "筛选条件"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }
        }

        //------------------------------------
        // 四列
        //------------------------------------

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ////////////////////////////////////////////////////
            // 难度范围
            ////////////////////////////////////////////////////

            Rectangle {

                Layout.fillWidth: true
                Layout.minimumWidth: 190
                implicitHeight: 150

                radius: 8
                color: "#162132"

                border.color: "#26364A"

                ColumnLayout {

                    anchors.fill: parent
                    anchors.margins: 10

                    spacing: 6

                    Label {
                        text: "难度范围"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 14
                    }

                    Label {
                        text: "最低星级"
                        color: "#C9D2E3"
                        font.pixelSize: 11
                    }

                    Row {
                        spacing: 1

                        Repeater {
                            model: 10

                            delegate: MouseArea {

                                width: 20
                                height: 20

                                onClicked: {
                                    panel.selectedMinLevel = index + 1

                                    if(panel.selectedMaxLevel <
                                            panel.selectedMinLevel)
                                        panel.selectedMaxLevel =
                                                panel.selectedMinLevel
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text:
                                    (index + 1)
                                    <= panel.selectedMinLevel
                                    ? "★"
                                    : "☆"

                                    font.pixelSize: 16

                                    color:
                                    (index + 1)
                                    <= panel.selectedMinLevel
                                    ? "#6DA9FF"
                                    : "#5B657A"
                                }
                            }
                        }
                    }

                    Label {
                        text: "最高星级"
                        color: "#C9D2E3"
                        font.pixelSize: 11
                    }

                    Row {
                        spacing: 1

                        Repeater {
                            model: 10

                            delegate: MouseArea {

                                width: 20
                                height: 20

                                onClicked: {

                                    panel.selectedMaxLevel = index + 1

                                    if(panel.selectedMinLevel >
                                            panel.selectedMaxLevel)
                                        panel.selectedMinLevel =
                                                panel.selectedMaxLevel
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text:
                                    (index + 1)
                                    <= panel.selectedMaxLevel
                                    ? "★"
                                    : "☆"

                                    font.pixelSize: 16

                                    color:
                                    (index + 1)
                                    <= panel.selectedMaxLevel
                                    ? "#6DA9FF"
                                    : "#5B657A"
                                }
                            }
                        }
                    }
                }
            }

            ////////////////////////////////////////////////////
            // 分类筛选
            ////////////////////////////////////////////////////

            Rectangle {

                Layout.fillWidth: true
                Layout.minimumWidth: 155
                implicitHeight: 150

                radius: 8
                color: "#162132"

                border.color: "#26364A"

                ColumnLayout {

                    anchors.fill: parent
                    anchors.margins: 10

                    spacing: 6

                    Label {
                        text: "分类筛选"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 14
                    }

                    Label {
                        text: "歌曲类型"
                        color: "#C9D2E3"
                        font.pixelSize: 11
                    }

                    ComboBox {

                        Layout.fillWidth: true

                        model: songModel
                               ? songModel.genres
                               : ["全部"]

                        onCurrentTextChanged:
                            panel.selectedGenre = currentText
                    }

                    Label {
                        text: "演奏难度"
                        color: "#C9D2E3"
                        font.pixelSize: 11
                    }

                    ComboBox {

                        Layout.fillWidth: true

                        model: songModel
                               ? songModel.courses
                               : ["全部"]

                        onCurrentTextChanged:
                            panel.selectedCourse = currentText
                    }
                }
            }

            ////////////////////////////////////////////////////
            // 排序规则
            ////////////////////////////////////////////////////

            Rectangle {

                Layout.fillWidth: true
                Layout.minimumWidth: 165
                implicitHeight: 150

                radius: 8
                color: "#162132"

                border.color: "#26364A"

                ColumnLayout {

                    anchors.fill: parent
                    anchors.margins: 10

                    spacing: 6

                    Label {
                        text: "排序规则"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 14
                    }

                    Label {
                        text: "排序字段"
                        color: "#C9D2E3"
                        font.pixelSize: 11
                    }

                    ComboBox {

                        Layout.fillWidth: true

                        model: [
                            "title",
                            "genreTitle",
                            "maxLevel",
                            "duration"
                        ]

                        onCurrentTextChanged:
                            panel.selectedSortField = currentText
                    }

                    RowLayout {

                        RadioButton {

                            text: "升序"
                            checked: true

                            onCheckedChanged:
                                if(checked)
                                    panel.selectedSortAsc = true
                        }

                        RadioButton {

                            text: "降序"
                            onCheckedChanged:
                                if(checked)
                                    panel.selectedSortAsc = false
                        }
                    }
                }
            }

            ////////////////////////////////////////////////////
            // 操作
            ////////////////////////////////////////////////////

            Rectangle {

                Layout.preferredWidth: 140
                implicitHeight: 150

                radius: 8

                color: "#162132"
                border.color: "#26364A"

                ColumnLayout {

                    anchors.fill: parent
                    anchors.margins: 10

                    spacing: 8

                    Label {
                        text: "操作"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 14
                    }

                    Button {

                        Layout.fillWidth: true
                        text: "开始筛选"

                        background: Rectangle {
                            radius: 8
                            color: "#8B5CF6"
                        }

                        onClicked: {

                            if(!songModel)
                                return

                            songModel.applyFilter(
                                        panel.selectedMinLevel,
                                        panel.selectedMaxLevel,
                                        panel.selectedGenre,
                                        panel.selectedCourse)

                            songModel.applySort(
                                        panel.selectedSortField,
                                        panel.selectedSortAsc)
                        }
                    }

                    Button {

                        Layout.fillWidth: true
                        text: "恢复默认"

                        background: Rectangle {
                            radius: 8
                            color: "#26364A"
                        }

                        onClicked: {

                            if(!songModel)
                                return

                            songModel.restoreDefaults()

                            panel.selectedMinLevel = 0
                            panel.selectedMaxLevel = 0

                            panel.selectedGenre = "全部"
                            panel.selectedCourse = "全部"

                            panel.selectedSortField = "title"
                            panel.selectedSortAsc = true
                        }
                    }

                    Button {

                        Layout.fillWidth: true
                        text: "重载歌曲库"

                        background: Rectangle {
                            radius: 8
                            color: "#26364A"
                        }

                        onClicked: {
                            songModel.reloadSongs()
                        }
                    }
                }
            }
        }
    }
}