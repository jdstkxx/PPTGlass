@echo off
rem 编译单文件 exe（需先安装 AutoHotkey 1.1；Ahk2Exe 在 AHK 安装目录 Compiler 下）
rem 本目录需先按 README 放入 DSEG7.ttf / alarm1.wav / alarm2.wav
set AHK=C:\Program Files\AutoHotkey
"%AHK%\Compiler\Ahk2Exe.exe" /silent verbose /in "%~dp0pptglass.ahk" /out "%~dp0..\pptglass.exe" /base "%AHK%\AutoHotkeyU64.exe" /compress 0
echo done: ..\pptglass.exe
