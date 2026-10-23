# 歌曲排序工具 (Song Sorter)

游戏运行目录 `D:\TaikoNijiiroDondaEX Ver4.1\TaikoNijiiroDondaEX Ver4.1`，扫描 Songs 子目录下的 TJA 谱面文件，提供筛选、排序、列表、谱面预览、AI 作谱等功能。

## 项目结构

```
歌曲排序工具/
├── main.qml                              # 应用入口 QML（TabBar + StackLayout）
├── songsorter.pro                        # Qt qmake 工程文件
├── .vscode/launch.json                   # VS Code 调试配置
│
├── src/                                  # C++ 逻辑层
│   ├── app/                              # 应用程序入口
│   │   ├── main.cpp                      # 主函数（窗口初始化 / CLI / dev 模式）
│   │   └── QmlLiveReload.h / .cpp        # QML 热重载（监视文件 → 语法探测 → 重载）
│   ├── core/                             # 核心业务逻辑
│   │   ├── SongInfo.h                    # 数据结构定义（SongInfo/CourseInfo/CourseChart）
│   │   ├── ChartData.h                   # ChartView：C++ ↔ QML 的谱面数据契约（Q_GADGET）
│   │   ├── TjaValidator.h / .cpp         # TJA 解析与合法性校验（纯函数，无 GUI 依赖）
│   │   ├── SongScanner.h / .cpp          # TJA 文件扫描与解析
│   │   └── SongModel.h / .cpp            # QML 数据模型（筛选/排序/谱面数据）
│   ├── ai/                               # AI 服务
│   │   └── DeepSeekClient.h / .cpp       # DeepSeek API 客户端（调用 AI 生成谱面）
│   └── utils/                            # 工具类
│       └── Logger.h / .cpp               # 单例日志管理器
│
├── ui/                                   # QML UI 层（按层级组织）
│   ├── pages/                            # 业务页面
│   │   ├── qmldir
│   │   ├── FilterSortPage.qml            # 筛选与排序 Tab 页面
│   │   └── AIGeneratePage.qml            # AI 谱面生成 Tab 页面
│   ├── panels/                           # 面板组件
│   │   ├── qmldir
│   │   ├── FilterPanel.qml               # 筛选条件面板
│   │   ├── FilterStatusPanel.qml         # 筛选状态摘要面板
│   │   ├── ToolPanel.qml                 # 导出工具面板
│   │   └── DebugPanel.qml                # 调试日志面板
│   └── views/                            # 视图组件
│       ├── qmldir
│       ├── SongListView.qml              # 歌曲列表视图
│       └── SongDetail.qml                # 谱面详情窗口
│
├── res/                                  # 静态资源
│   └── Notes.png                         # 音符精灵图
│
├── release/                              # Release 构建输出（运行时目录）
│   ├── SongSorter.exe
│   ├── main.qml                          # 同步的 QML 文件
│   ├── ui/                               # 同步的 UI 层
│   └── res/
│
└── debug/                                # Debug 构建输出
    ├── SongSorter.exe
    └── ...
```

## 层级依赖关系

```
main.qml
  → import "ui/pages"    (FilterSortPage, AIGeneratePage)
  → import "ui/panels"   (DebugPanel)
  → import "ui/views"    (SongDetail)

FilterSortPage.qml
  → ../panels            (FilterPanel, FilterStatusPanel, ToolPanel)
  → ../views             (SongListView)

AIGeneratePage.qml
  → ../views             (SongDetail via detailWindow)

C++ 层：
  main.cpp → core/SongModel.h, ai/DeepSeekClient.h, utils/Logger.h
  SongModel.cpp → core/SongScanner.h, utils/Logger.h
  SongScanner.cpp → utils/Logger.h
  DeepSeekClient.cpp → utils/Logger.h
```

## 编译方式

### 前置条件
- Visual Studio 2026 + MSVC
- Qt 6.10.1 (msvc2022_64)
- OpenSSL（Qt Network 需要）

### Release 编译

```powershell
cmd /c "VsDevCmd.bat -arch=amd64 && cd /d e:\歌曲排序工具 && nmake -f Makefile.Release clean && del /q .qmake.stash Makefile* && qmake -spec win32-msvc songsorter.pro && nmake -f Makefile.Release"
copy .\main.qml .\release\main.qml /Y
# + 复制 ui/ 目录到 release/ui/
```

### Debug 编译（VS Code 可调试）

```powershell
cmd /c "VsDevCmd.bat -arch=amd64 && cd /d e:\歌曲排序工具 && nmake -f Makefile.Debug clean && del /q .qmake.stash Makefile* && qmake -spec win32-msvc "CONFIG+=debug" songsorter.pro && nmake -f Makefile.Debug"
```

VS Code 调试配置见 `.vscode/launch.json`（`cppvsdbg` + `debug/SongSorter.exe`）。

## 开发模式（QML 热重载）

只改界面时不用重新编译，存盘即生效：

```powershell
.\release\SongSorter.exe --dev
.\release\SongSorter.exe --dev --qml-dir "E:\歌曲排序工具"   # 显式指定源码目录
```

- 直接从源码目录加载 `main.qml` 与 `ui/`，不再依赖 `release/` 里的副本
- 监视 16 个 QML 文件及其所在目录，存盘后约 1 秒自动重载
- 重载前只对**本次改动的文件**做语法探测：写错了会在 `release\dev.log` 里报错，并**保留旧窗口**
- 业务对象（SongModel 等）挂在 QApplication 上而非 engine 上，重载不会丢已加载的歌曲列表
- 日志写入 `release\dev.log`，已过滤掉 Controls 样式类的高频噪音

## QML 静态检查

`qmllint` 已接进构建脚本，编译前自动执行，能抓到拼错的属性名、未声明变量、Layout 误用等：

```powershell
.\build_release.cmd                 # 构建（含 lint）
.\build_release.cmd --skip-lint     # 跳过 lint
powershell -File tools\lint_qml.ps1 # 只跑检查
```

采用**基线比对**（`tools/qmllint-baseline.json`）：只对新增问题返回失败，历史遗留问题不会挡住构建。

```powershell
# 修完历史问题后，把当前结果固化为新基线
powershell -File tools\lint_qml.ps1 -UpdateBaseline
```

`unqualified`（本项目大量使用 context property，必然出现）与 `Quick.color`（`#999` 这类三位缩写 Qt 是支持的）已在 `.qmllint.ini` 降为 info，不计入基线。

## QML 文件同步

编译只处理 C++ 代码，QML 文件需手动（或通过脚本）复制到构建输出目录（`release/` 或 `debug/`）。

## AI 谱面生成

API Key **不再硬编码**，按以下优先级读取：

1. 环境变量 `DEEPSEEK_API_KEY`
2. 程序目录下的 `config.json`：`{ "deepseekApiKey": "sk-..." }`（已在 .gitignore 中）
3. 都没有时为空，界面里可手动填写

- 通过 DeepSeek Chat API（`deepseek-chat` 模型）生成太鼓达人 TJA 谱面
- 生成完成后自动保存到指定输出目录（默认为 `{游戏根目录}/Songs/AI_Generated`）
- 同时打开 SongDetail 窗口预览生成的谱面，并给出谱面校验结论

## 功能一览

| 功能 | 说明 |
|------|------|
| TJA 扫描 | 按分类扫描 Songs 目录，解析多语言编码（Shift-JIS/UTF-8/GBK） |
| 筛选排序 | 按星级/流派/难度筛选，按标题/流派/星级/时长排序 |
| 谱面预览 | 点击歌曲加载真实 TJA 谱面数据，逐小节显示音符图 |
| AI 作谱 | 上传 .ogg 音频文件，DeepSeek AI 自动生成 TJA 谱面并保存 |
| 导出 | CSV/JSON 导出当前筛选结果；筛选歌曲复制到子目录 |
| 游戏重启 | 一键重启 taiko.exe / donda.exe |
| 调试日志 | 带 Tag 的日志系统，面板实时显示 |




## 谱面说明 -- 重要 -- 

## 谱面 数字含义作为一个note
0 : 空位
1 : 咚
2 : 咔
3 : 咚（大）
4 : 咔（大）
5 : 连打开始
6 : 连打（大）开始
7 : 气球连打开始
8 : 连打终了
（Ver.2.75以后）
9 : 地瓜连打开始

连打输入格式范例:
500008或555558


## 谱面 小节数

四分音符为一拍，每小节有四拍
其中对于每一个note，共可能有1分、2分、4分、8分、16分、32分
3分、6分、12分、24分、48分这些

每一小节间使用","分隔  
该小节的最小单位即以一除数字的总数  
例:一行#MEASURE 4/4的谱面中有16个数字，那么该小节中一个数字所占的单位是16分音  
此外，一小节的最大可有约500个数字，若过长将可能出错而导致程序关闭




## TODOLIST
需要完善dump捕获机制

如何创作歌曲谱面：
https://diane30087.github.io/
https://www.douban.com/group/topic/33159512/?_i=066788651CJsus
https://tja.snack.studio/


获取歌曲封面：
https://developer.apple.com/documentation/applemusicapi/get-a-catalog-song