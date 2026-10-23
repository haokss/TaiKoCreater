.pragma library

// res/Notes.png 雪碧图切分（坐标由脚本扫描 alpha 通道实测）
// 第 1 行是完整的一套：小咚/小咔/大咚/大咔/连打开始/连打条/大连打/大条/气球

function clipFor(type) {
    switch (String(type)) {
    case "1": return Qt.rect(158, 30, 71, 70)     // 咚
    case "2": return Qt.rect(288, 30, 71, 70)     // 咔
    case "3": return Qt.rect(401, 12, 106, 106)   // 咚（大）
    case "4": return Qt.rect(531, 12, 106, 106)   // 咔（大）
    case "5": return Qt.rect(678, 30, 71, 70)     // 连打开始
    case "6": return Qt.rect(1051, 12, 106, 106)  // 大连打开始
    case "7": return Qt.rect(1458, 30, 177, 70)   // 气球
    case "9": return Qt.rect(1458, 30, 177, 70)   // 地瓜
    default:  return Qt.rect(158, 30, 71, 70)
    }
}

// 图标高度
function sizeFor(type) {
    var t = String(type)
    return (t === "3" || t === "4" || t === "6") ? 34 : 24
}

// 图标宽度（气球/地瓜是横向长条，按原始 177x70 比例给足宽度）
function widthFor(type) {
    var t = String(type)
    if (t === "7" || t === "9")
        return 48
    return sizeFor(t)
}
