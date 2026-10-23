import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import "../panels"
import "../views"

// AI 作谱 Tab 页
Item {
    id: root

    property string selectedGenre: "J-POP"
    property string selectedDifficulty: "Oni"
    property int targetLevel: 8
    property int targetBpm: 150
    property string generationStatus: ""
    property string apiKey: deepSeek ? deepSeek.apiKey : ""
    property string uploadedOggPath: ""
    property string uploadedFileName: ""
    property string outputDirectory: ""

    // 默认输出目录：{游戏根目录}/Songs/AI_Generated
    Component.onCompleted: {
        var base = songModel ? songModel.currentRoot : "";
        if (base) {
            outputDirectory = base.replace(/\\/g, "/") + "/Songs/AI_Generated";
        }
    }

    // ── 接收 DeepSeek 信号 ──
    Connections {
        target: deepSeek
        enabled: deepSeek !== null

        function onGenerationProgress(msg) {
            root.generationStatus = msg;
        }

        function onGenerationCompleted(tjaContent) {
            var chartData = songModel.parseGeneratedTJA(tjaContent);

            var dir = root.outputDirectory;
            if (dir && songModel) {
                var ts = new Date().toISOString().replace(/[:.]/g, "-").substring(0, 19);
                var fileName = root.selectedGenre + "_" + root.selectedDifficulty + "_Lv" + root.targetLevel + "_BPM" + root.targetBpm + "_" + ts + ".tja";
                var saved = songModel.saveGeneratedTJA(dir, fileName);
                root.generationStatus = saved ? "生成完成 ✓ 已保存" : "生成完成 ✗ 保存失败";
            } else {
                root.generationStatus = "生成完成（未设置输出目录）";
            }

            if (chartData && chartData.measureLines && chartData.measureLines.length > 0) {
                var courseDataList = [
                    {
                        course: chartData.course || "AI Generated",
                        level: chartData.level || 0,
                        notes: chartData.measureLines
                    }
                ];
                detailWindow.realTitle = uploadedFileName || "AI Generated";
                detailWindow.realBpm = chartData.bpm || 0;
                detailWindow.realGenre = selectedGenre;
                detailWindow.realCourses = courseDataList;
                detailWindow.selectedCourseIndex = 0;
                detailWindow.show();
                detailWindow.raise();
            }

            var record = "[" + new Date().toLocaleTimeString() + "] " + root.selectedGenre + " · " + root.selectedDifficulty + " ★" + root.targetLevel + " · BPM " + root.targetBpm + " · " + (root.uploadedFileName || "无文件");
            historyModel.insert(0, {
                data: record
            });
        }

        function onGenerationFailed(errorMsg) {
            root.generationStatus = "失败: " + errorMsg;
            var record = "[" + new Date().toLocaleTimeString() + "] 失败: " + errorMsg;
            historyModel.insert(0, {
                data: record
            });
        }
    }

    FileDialog {
        id: fileDialog
        title: "选择 OGG 音频文件"
        nameFilters: ["OGG 音频文件 (*.ogg)", "所有文件 (*.*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            var chosenFile = fileDialog.currentFile || fileDialog.selectedFile;
            if (chosenFile) {
                var urlStr = chosenFile.toString();
                var localPath = urlStr.replace(/^file:\/{3}/, "");
                if (Qt.platform.os === "windows")
                    localPath = localPath.replace(/\//g, "\\");
                root.uploadedOggPath = chosenFile;
                var parts = localPath.split("\\");
                root.uploadedFileName = parts[parts.length - 1];
                root.generationStatus = "已选择: " + root.uploadedFileName;
            }
        }
        onRejected: {
            root.generationStatus = "未选择文件";
        }
    }

    FolderDialog {
        id: folderDialog
        title: "选择 TJA 输出目录"
        onAccepted: {
            var chosenFolder = folderDialog.currentFolder || folderDialog.selectedFolder;
            if (chosenFolder) {
                var urlStr = chosenFolder.toString();
                var localPath = urlStr.replace(/^file:\/{3}/, "");
                if (Qt.platform.os === "windows")
                    localPath = localPath.replace(/\//g, "\\");
                root.outputDirectory = localPath;
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        background: Rectangle {
            color: "#FFFFFF"
        }

        ColumnLayout {
            width: parent ? parent.width - 20 : 750
            spacing: 16
            anchors.margins: 16

            // ── 标题 ──
            Text {
                text: "AI 谱面生成"
                font.bold: true
                font.pointSize: 20
                color: "#E60012"
            }

            Text {
                text: "上传 .ogg 音频文件，通过 DeepSeek AI 自动生成太鼓达人 .tja 谱面"
                font.pointSize: 11
                color: "#999"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // ── API Key ──
            GroupBox {
                title: "API 设置"
                Layout.preferredWidth: 650
                background: Rectangle {
                    color: "#FAFAFA"
                    radius: 8
                    border.color: "#E0E0E0"
                    border.width: 1
                }
                label: Text {
                    text: parent.title
                    color: "#E60012"
                    font.bold: true
                    font.pointSize: 13
                }

                RowLayout {
                    spacing: 12
                    Text {
                        text: "DeepSeek API Key:"
                        color: "#222"
                    }
                    TextField {
                        id: apiKeyField
                        Layout.preferredWidth: 350
                        placeholderText: "sk-xxxxxxxxxxxxxxxxxxxxxxxx"
                        echoMode: TextInput.Password
                        text: root.apiKey
                        onTextChanged: {
                            if (deepSeek)
                                deepSeek.apiKey = text;
                        }
                        background: Rectangle {
                            color: "#F5F5F5"
                            radius: 4
                            border.color: "#DDD"
                        }
                    }
                    Button {
                        text: apiKeyField.echoMode === TextInput.Password ? "显示" : "隐藏"
                        onClicked: {
                            apiKeyField.echoMode = apiKeyField.echoMode === TextInput.Password ? TextInput.Normal : TextInput.Password;
                        }
                        background: Rectangle {
                            color: "#F0F0F0"
                            radius: 4
                            border.color: "#DDD"
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#666"
                            font.pointSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // ── 输出目录 ──
            GroupBox {
                title: "输出目录"
                Layout.preferredWidth: 650
                background: Rectangle {
                    color: "#FAFAFA"
                    radius: 8
                    border.color: "#E0E0E0"
                    border.width: 1
                }
                label: Text {
                    text: parent.title
                    color: "#E60012"
                    font.bold: true
                    font.pointSize: 13
                }

                RowLayout {
                    spacing: 12
                    Button {
                        text: "选择目录"
                        onClicked: folderDialog.open()
                        background: Rectangle {
                            color: "#FF9800"
                            radius: 6
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    TextField {
                        id: outputDirField
                        Layout.fillWidth: true
                        text: root.outputDirectory
                        placeholderText: "AI 生成谱面的保存路径"
                        onTextChanged: root.outputDirectory = text
                        background: Rectangle {
                            color: "#F5F5F5"
                            radius: 4
                            border.color: "#DDD"
                        }
                    }
                    Button {
                        text: "重置默认"
                        onClicked: {
                            var base = songModel ? songModel.currentRoot : "";
                            root.outputDirectory = base ? base.replace(/\\/g, "/") + "/Songs/AI_Generated" : "";
                        }
                        background: Rectangle {
                            color: "#F0F0F0"
                            radius: 4
                            border.color: "#DDD"
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#666"
                            font.pointSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // ── 上传 OGG ──
            GroupBox {
                title: "音频文件"
                Layout.preferredWidth: 650
                background: Rectangle {
                    color: "#FAFAFA"
                    radius: 8
                    border.color: "#E0E0E0"
                    border.width: 1
                }
                label: Text {
                    text: parent.title
                    color: "#E60012"
                    font.bold: true
                    font.pointSize: 13
                }

                RowLayout {
                    spacing: 12
                    Button {
                        text: "选择 OGG 文件"
                        onClicked: fileDialog.open()
                        background: Rectangle {
                            color: "#4CAF50"
                            radius: 6
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    Text {
                        text: root.uploadedFileName || "未选择文件"
                        color: root.uploadedFileName ? "#222" : "#999"
                        font.pointSize: 11
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                    }
                }
            }

            // ── 生成参数 ──
            GroupBox {
                title: "生成参数"
                Layout.preferredWidth: 650
                background: Rectangle {
                    color: "#FAFAFA"
                    radius: 8
                    border.color: "#E0E0E0"
                    border.width: 1
                }
                label: Text {
                    text: parent.title
                    color: "#E60012"
                    font.bold: true
                    font.pointSize: 13
                }

                GridLayout {
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 20
                    Text {
                        text: "歌曲类型："
                        color: "#222"
                    }
                    ComboBox {
                        model: ["J-POP", "Anime", "VOCALOID", "Game Music", "Classical", "Variety", "Children's Song", "Namco Original"]
                        currentIndex: 0
                        onCurrentTextChanged: root.selectedGenre = currentText
                        background: Rectangle {
                            color: "#F5F5F5"
                            radius: 4
                            border.color: "#DDD"
                        }
                        contentItem: Text {
                            text: parent.displayText
                            color: "#333"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 8
                        }
                    }
                    Text {
                        text: "目标难度："
                        color: "#222"
                    }
                    ComboBox {
                        model: ["Easy", "Normal", "Hard", "Oni", "Ura"]
                        currentIndex: 3
                        onCurrentTextChanged: root.selectedDifficulty = currentText
                        background: Rectangle {
                            color: "#F5F5F5"
                            radius: 4
                            border.color: "#DDD"
                        }
                        contentItem: Text {
                            text: parent.displayText
                            color: "#333"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 8
                        }
                    }
                    Text {
                        text: "目标星级 (1~10)："
                        color: "#222"
                    }
                    SpinBox {
                        from: 1
                        to: 10
                        value: root.targetLevel
                        onValueChanged: root.targetLevel = value
                    }
                    Text {
                        text: "BPM："
                        color: "#222"
                    }
                    SpinBox {
                        from: 30
                        to: 400
                        value: root.targetBpm
                        stepSize: 5
                        onValueChanged: root.targetBpm = value
                    }
                }
            }

            // ── 高级选项 ──
            GroupBox {
                title: "高级选项"
                Layout.preferredWidth: 650
                background: Rectangle {
                    color: "#FAFAFA"
                    radius: 8
                    border.color: "#E0E0E0"
                    border.width: 1
                }
                label: Text {
                    text: parent.title
                    color: "#E60012"
                    font.bold: true
                    font.pointSize: 13
                }

                ColumnLayout {
                    spacing: 10
                    RowLayout {
                        spacing: 10
                        CheckBox {
                            id: cbVariation
                            text: "添加节奏变化"
                            checked: true
                        }
                        CheckBox {
                            id: cbGogo
                            text: "包含 GO-GO TIME"
                            checked: true
                        }
                        CheckBox {
                            id: cbBranch
                            text: "包含分支谱面"
                            checked: false
                        }
                    }
                    RowLayout {
                        spacing: 10
                        Text {
                            text: "音符密度："
                            color: "#222"
                        }
                        Slider {
                            id: densitySlider
                            from: 0.3
                            to: 1.0
                            value: 0.6
                            stepSize: 0.05
                            Layout.preferredWidth: 200
                        }
                        Text {
                            text: densitySlider.value.toFixed(2)
                            color: "#666"
                            Layout.preferredWidth: 30
                        }
                    }
                }
            }

            // ── 生成按钮 ──
            RowLayout {
                spacing: 16
                Button {
                    text: deepSeek && deepSeek.busy ? "生成中..." : "生成谱面"
                    enabled: !(deepSeek && deepSeek.busy) && root.uploadedOggPath !== ""
                    onClicked: {
                        if (!deepSeek) {
                            root.generationStatus = "错误: DeepSeek 客户端未初始化";
                            return;
                        }
                        root.generationStatus = "生成中...";
                        deepSeek.generateTJA(root.uploadedOggPath, selectedGenre, selectedDifficulty, targetLevel, targetBpm, cbVariation.checked, cbGogo.checked, cbBranch.checked, densitySlider.value);
                    }
                    background: Rectangle {
                        color: parent.enabled ? "#E60012" : "#CCC"
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        font.pointSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Button {
                    text: "取消"
                    enabled: deepSeek && deepSeek.busy
                    onClicked: {
                        if (deepSeek)
                            deepSeek.cancelGeneration();
                        root.generationStatus = "已取消";
                    }
                    background: Rectangle {
                        color: "#F0F0F0"
                        radius: 4
                        border.color: "#DDD"
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#666"
                        font.pointSize: 10
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Text {
                    text: root.generationStatus
                    color: root.generationStatus.includes("已保存") ? "#4CAF50" : root.generationStatus.startsWith("失败") ? "#E60012" : "#FF9800"
                    font.bold: true
                    font.pointSize: 11
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // ── 生成历史 ──
            GroupBox {
                title: "生成历史"
                Layout.fillWidth: true
                Layout.minimumHeight: 150
                Layout.fillHeight: true
                background: Rectangle {
                    color: "#FAFAFA"
                    radius: 8
                    border.color: "#E0E0E0"
                    border.width: 1
                }
                label: Text {
                    text: parent.title
                    color: "#E60012"
                    font.bold: true
                    font.pointSize: 13
                }

                ListView {
                    anchors.fill: parent
                    model: ListModel {
                        id: historyModel
                    }
                    delegate: Rectangle {
                        width: parent ? parent.width : 600
                        height: 36
                        color: index % 2 ? "#F5F5F5" : "#FFFFFF"
                        border.color: "#EEE"
                        Text {
                            anchors.fill: parent
                            anchors.margins: 8
                            text: modelData
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            font.pointSize: 10
                            color: "#333"
                        }
                    }
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }
            }
        }
    }
}
