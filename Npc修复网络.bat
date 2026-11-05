@echo off
rem ===========================================================================
rem  Npc - One-Click Network Recovery
rem  一键恢复网络 · 双击此文件即可，无需重启电脑
rem ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion

set "HERE=%~dp0"
set "GUI=%HERE%Npc修复网络-GUI.ps1"
set "CONSOLE_ENGINE=%HERE%Npc修复网络.ps1"

title Npc

rem --- 1. 检查文件是否齐全 -----------------------------------------------------
if not exist "%GUI%" goto NOGUI
if not exist "%CONSOLE_ENGINE%" goto NOENGINE

rem --- 2. 检查管理员权限 -------------------------------------------------------
net session >nul 2>&1
if %errorlevel%==0 goto RUN

echo.
echo   Requesting administrator privileges / 正在申请管理员权限...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p='%~f0'; Start-Process -FilePath $p -Verb RunAs -WindowStyle Hidden" >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] Elevation cancelled. / 提权被取消。
    echo   Right-click this file and choose "Run as administrator".
    echo   请右键此文件，选择「以管理员身份运行」。
    echo.
    pause
)
exit /b 0

rem --- 3. 以管理员身份启动 WPF 图形界面 ----------------------------------------
:RUN
powershell -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%GUI%"
set "RC=%errorlevel%"

if "%RC%"=="0" goto DONE

rem --- 4. GUI 失败时自动降级到控制台版（保证永远有救）--------------------------
echo.
echo   [WARN] GUI mode exited with code %RC%.
echo   [警告] 图形界面启动失败，自动切换到控制台修复模式...
echo   控制台模式一样能修好网络，请按提示操作。
echo.
timeout /t 2 /nobreak >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%CONSOLE_ENGINE%"
goto DONE

rem --- 错误出口 ---------------------------------------------------------------
:NOGUI
echo.
echo   [ERROR] Missing file: Npc修复网络-GUI.ps1
echo   [错误] 缺少文件 Npc修复网络-GUI.ps1
echo.
echo   Make sure ALL files are in the SAME folder:
echo     - Npc修复网络-GUI.ps1
echo     - Npc修复网络.ps1
echo     - This .bat file
echo.
echo   请确认以下文件在同一个文件夹里：
echo     - Npc修复网络-GUI.ps1
echo     - Npc修复网络.ps1
echo     - 本 .bat 文件
echo.
pause
exit /b 1

:NOENGINE
echo.
echo   [ERROR] Missing file: Npc修复网络.ps1
echo   [错误] 缺少文件 Npc修复网络.ps1
echo.
pause
exit /b 1

:DONE
endlocal
exit /b 0
