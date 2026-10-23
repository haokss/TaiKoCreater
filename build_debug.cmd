@echo off
REM ============================================================
REM  Debug 构建脚本
REM  用法: build_debug.cmd [--no-run]
REM    --no-run  仅编译，不启动程序（供 VS Code preLaunchTask 用）
REM ============================================================
setlocal enabledelayedexpansion

set TARGET_EXE=SongSorter.exe
set RUN_FLAG=1
if /i "%~1"=="--no-run" set RUN_FLAG=0

if not exist "E:\Visual Studio 2026\Visual Studio\VC\Auxiliary\Build\vcvarsall.bat" (
    echo [ERROR] 找不到 vcvarsall.bat
    exit /b 1
)

echo [1/4] 终止旧进程...
taskkill /f /im "%TARGET_EXE%" >nul 2>&1
echo       已处理

echo [2/4] 初始化 MSVC 环境...
call "E:\Visual Studio 2026\Visual Studio\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] vcvarsall 失败
    exit /b 1
)

echo [3/4] 同步文件...
xcopy /s /d /y "ui\*" "debug\ui\" >nul
copy /y "main.qml" "debug\main.qml" >nul
xcopy /s /d /y "res" "debug\res\" >nul
echo       完成

echo [4/4] 编译 Debug...
nmake /f Makefile.Debug
if errorlevel 1 (
    echo [ERROR] 编译失败
    exit /b 1
)

echo.
echo ============================================================
echo  构建完成: debug\%TARGET_EXE%
echo ============================================================

if %RUN_FLAG%==1 (
    echo  启动程序...
    start "" "debug\%TARGET_EXE%"
)
endlocal