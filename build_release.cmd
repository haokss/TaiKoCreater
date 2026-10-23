@echo off
REM ============================================================
REM  Release 构建脚本
REM  用法: build_release.cmd [--no-run] [--skip-lint]
REM    --no-run     仅编译，不启动程序（供 VS Code preLaunchTask 用）
REM    --skip-lint  跳过 QML 静态检查（等不及的时候用）
REM ============================================================
setlocal enabledelayedexpansion

set TARGET_EXE=SongSorter.exe
set RUN_FLAG=1
set LINT_FLAG=1
for %%a in (%*) do (
    if /i "%%a"=="--no-run" set RUN_FLAG=0
    if /i "%%a"=="--skip-lint" set LINT_FLAG=0
)

if not exist "E:\Visual Studio 2026\Visual Studio\VC\Auxiliary\Build\vcvarsall.bat" (
    echo [ERROR] 找不到 vcvarsall.bat
    exit /b 1
)

echo [1/7] 终止旧进程...
taskkill /f /im "%TARGET_EXE%" >nul 2>&1
echo       已处理

echo [2/7] 清除 QML 缓存...
if exist "release\qml" rmdir /s /q "release\qml"
if exist "release\qmlcache" rmdir /s /q "release\qmlcache"
del /q "release\*.qmlc" 2>nul
del /q "release\*.jsc" 2>nul
echo       完成

echo [3/7] QML 静态检查...
if %LINT_FLAG%==0 (
    echo       已跳过 --skip-lint
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "tools\lint_qml.ps1"
    if errorlevel 1 (
        echo.
        echo [ERROR] QML 检查发现新增问题，已中止构建。
        echo         修完后重试；确实要跳过请加 --skip-lint
        exit /b 1
    )
)

echo [4/7] 初始化 MSVC 环境...
call "E:\Visual Studio 2026\Visual Studio\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] vcvarsall 失败
    exit /b 1
)

echo [5/7] 同步文件...
xcopy /s /d /y "ui\*" "release\ui\" >nul
copy /y "main.qml" "release\main.qml" >nul
xcopy /s /d /y "res" "release\res\" >nul
if not exist "release\tools" mkdir "release\tools"
xcopy /s /d /y "tools\*" "release\tools\" >nul
echo       完成

echo [6/7] 编译 Release...
nmake /f Makefile.Release
if errorlevel 1 (
    echo [ERROR] 编译失败
    exit /b 1
)

echo [7/7] 部署 Qt 运行库...
windeployqt "release\%TARGET_EXE%" --qmldir "." 
if errorlevel 1 (
    echo [WARNING] windeployqt 返回错误码，程序可能缺少依赖库
)

echo.
echo ============================================================
echo  构建完成: release\%TARGET_EXE%
echo  开发模式: release\%TARGET_EXE% --dev  (改 QML 存盘即生效)
echo ============================================================

if %RUN_FLAG%==1 (
    echo  启动程序...
    start "" "release\%TARGET_EXE%"
)
endlocal
