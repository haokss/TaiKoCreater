import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "../panels"
import "../views"

// 筛选排序 Tab 页
Item {
    id: root

    signal songClicked(string title, real bpm, string genre, var courses, int index)

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // ── 游戏根目录路径栏 ──
        RowLayout {
            spacing: 8
            Label {
                text: "游戏根目录："
                color: "white"
                font.bold: true
                font.pixelSize: 14
            }
            TextField {
                id: pathField
                Layout.preferredWidth: 400
                placeholderText: "游戏根目录路径 (如 D:/Taiko...)"
                text: songModel ? songModel.currentRoot : ""
                onAccepted: appWindow.loadPath(text)
            }
            Button {
                text: "加载"
                onClicked: appWindow.loadPath(pathField.text)
            }
        }

        // ── 筛选 / 状态 两栏 ──
        RowLayout {
            spacing: 12
            Layout.fillWidth: true

            FilterPanel {
                id: filterPanel
                Layout.fillWidth: true
                Layout.minimumWidth: 670
                implicitHeight: 200

                onStatusMessage: {
                    statusPanel.statusLabel.text = msg;
                }
            }

            FilterStatusPanel {
                id: statusPanel
                Layout.fillWidth: true
                Layout.minimumWidth: 220

                // 直接从 FilterPanel 实例读取筛选状态
                selectedMinLevel: filterPanel.selectedMinLevel
                selectedMaxLevel: filterPanel.selectedMaxLevel
                selectedGenre: filterPanel.selectedGenre
                selectedCourse: filterPanel.selectedCourse
                selectedSortField: filterPanel.selectedSortField
                selectedSortAsc: filterPanel.selectedSortAsc

                onExportCsv: exportCsv()
                onExportJson: exportJson()
            }
        }

        // ── 歌曲列表 ──
        SongListView {
            id: songListView
            Layout.fillWidth: true
            Layout.fillHeight: true

            onSongClicked: function (title, bpm, genre, courses, index) {
                root.songClicked(title, bpm, genre, courses, index);
            }
        }
    }

    function exportCsv() {
        if (!songModel)
            return;
        var arr = songModel.songs();
        var lines = ['"' + "title" + '","' + "genre" + '","' + "maxLevel" + '","' + "duration" + '"'];
        for (var i = 0; i < arr.length; ++i) {
            var s = arr[i];
            lines.push('"' + s.title + '","' + (s.genreTitle || s.genre) + '",' + s.maxLevel + ',' + s.duration.toFixed(1));
        }
        console.log("[CSV] 导出 " + arr.length + " 首歌曲");
        console.log(lines.join("\n"));
    }

    function exportJson() {
        if (!songModel)
            return;
        var arr = songModel.songs();
        console.log("[JSON] 导出 " + arr.length + " 首歌曲");
        console.log(JSON.stringify(songModel.songs(), null, 2));
    }
}
