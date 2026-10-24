; ppttimer_new.ahk — 《PPT播放提示钟》现代重制版 v3（GDI+ 整卡自绘）
; 功能对齐陈家琪 PPTTimer v1.22：PPT/WPS 放映自动开始/停止倒计时、手动计时、
; 预铃（声音+弹窗）、限时到点（声音+超时正计时+红闪）、暂停/继续、音量调节
; （设置窗内，退出还原）、自动隐藏、开机自启、ini 记忆、托盘/右键菜单。
; 界面：单张 GDI+ 抗锯齿位图经 UpdateLayeredWindow 呈现——圆角卡片、大数字、
; 进度条全部自绘，无原生控件，无裁切问题。窗口标题实时同步 LED 值供测试。
;@Ahk2Exe-SetName PPT沙漏 pptglass
;@Ahk2Exe-SetVersion 1.0.0
;@Ahk2Exe-SetDescription PPT沙漏
;@Ahk2Exe-SetCopyright Copyright (c) 2026 PPT沙漏 pptglass
#SingleInstance force
#NoEnv
SetBatchLines -1
DllCall("SetProcessDPIAware")

ptIni := A_ScriptDir "\ppttimer_new.ini"
IniRead, ptHour, %ptIni%, Main, LimitHour, 0
IniRead, ptMin, %ptIni%, Main, LimitMin, 10
IniRead, ptPre, %ptIni%, Main, PreAlarm, 2
IniRead, ptVol, %ptIni%, Main, Volume, 70
IniRead, ptOpacity, %ptIni%, Main, Opacity, 215
IniRead, ptPreFile, %ptIni%, Main, PreAlarmFile, %A_ScriptDir%\beep.mp3
IniRead, ptEndFile, %ptIni%, Main, EndAlarmFile, %A_ScriptDir%\applause.mp3
IniRead, ptMsg, %ptIni%, Main, TimeoutMsg, 时间到！请结束演讲
IniRead, ptAutoHide, %ptIni%, Main, AutoHide, 0
IniRead, ptAutoRun, %ptIni%, Main, AutoRun, 0
IniRead, ptShowClasses, %ptIni%, Main, showWindowClasses, screenClass
IniRead, ptShowProcs, %ptIni%, Main, showProcesses, wpp.exe`,wps.exe
IniRead, startKey, %ptIni%, shortcuts, startKey, F12
IniRead, stopKey, %ptIni%, shortcuts, stopKey, ^F12
IniRead, quitKey, %ptIni%, shortcuts, quitKey, #ESC

ptLimit := ptHour*60 + ptMin
if (ptLimit < 1)
    ptLimit := 1
if (ptLimit > 99)
    ptLimit := 99
ptRemain := ptLimit * 60
ptState := "idle"
ptShowOn := false
ptBlink := false
ptHover := false
ptDragging := false
SoundGet, ptVol0, Wave
if (ptVol0 = "")
    ptVol0 := ptVol

; ---------- GDI+ init ----------
VarSetCapacity(gsi, 24, 0)
NumPut(1, gsi, 0, "uint")
if (DllCall("gdiplus\GdiplusStartup", "uptr*", gToken := 0, "ptr", &gsi, "ptr", 0))
    ExitApp

; ---------- card window ----------
ptS := A_ScreenDPI / 96.0
CW := Round(200 * ptS)
CH := Round(78 * ptS)
CWu := Round(CW / ptS)
CHu := Round(CH / ptS)
Gui, Main:New, +HWNDhMain +AlwaysOnTop +ToolWindow -Caption +LastFound, PPT沙漏-计时
Gui, Main:Color, 000000
Gui, Main:Add, Pic, x0 y0 w%CWu% h%CHu% hwndhPic +0xE Background000000
Gui, Main:Show, Hide, PPT沙漏-计时
DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", CW, "int", CH, "int", 0, "uint", 0x26200A, "ptr", 0, "ptr*", gBmp := 0)
DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", gBmp, "ptr*", gGfx := 0)
DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gGfx, "int", 4)
DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gGfx, "int", 4)

DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Segoe UI", "ptr", 0, "ptr*", famBig := 0)
if (famBig = 0)
    DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Microsoft YaHei UI", "ptr", 0, "ptr*", famBig)
DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", "Microsoft YaHei UI", "ptr", 0, "ptr*", famCap := 0)
DllCall("gdiplus\GdipCreateFont", "ptr", famBig, "float", Round(38 * ptS), "int", 1, "int", 2, "ptr*", fBig := 0)
DllCall("gdiplus\GdipCreateFont", "ptr", famCap, "float", Round(9.5 * ptS), "int", 0, "int", 2, "ptr*", fCap := 0)
DllCall("gdiplus\GdipCreateFont", "ptr", famCap, "float", Round(12 * ptS), "int", 1, "int", 2, "ptr*", fBtn := 0)
famLed := 0
if FileExist(A_ScriptDir "\DSEG7.ttf") {
    DllCall("gdiplus\GdipNewPrivateFontCollection", "ptr*", fcol := 0)
    if (DllCall("gdiplus\GdipPrivateAddFontFile", "ptr", fcol, "wstr", A_ScriptDir "\DSEG7.ttf") = 0) {
        VarSetCapacity(famArr, 8, 0)
        if (DllCall("gdiplus\GdipGetFontCollectionFamilyList", "ptr", fcol, "int", 1, "ptr", &famArr, "int*", nFound := 0) = 0 && nFound >= 1)
            famLed := NumGet(famArr, 0, "ptr")
    }
}
fLed := 0
if (famLed != 0)
    DllCall("gdiplus\GdipCreateFont", "ptr", famLed, "float", Round(46 * ptS), "int", 1, "int", 2, "ptr*", fLed)
DllCall("gdiplus\GdipCreateStringFormat", "int", 0, "int", 0, "ptr*", sfL := 0)
DllCall("gdiplus\GdipCreateStringFormat", "int", 0, "int", 0, "ptr*", sfC := 0)
DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", sfL, "int", 0)
DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", sfL, "int", 0)
DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", sfC, "int", 1)
DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", sfC, "int", 1)

btnSetL := Round(146 * ptS), btnSetR := Round(168 * ptS)
btnExitL := Round(174 * ptS), btnExitR := Round(196 * ptS)
btnT := Round(5 * ptS), btnB := Round(29 * ptS)
btnAbtL := Round(4 * ptS), btnAbtR := Round(26 * ptS)

Gosub BuildMenu
OnMessage(0x201, "OnLDown")
OnMessage(0x203, "OnLDbl")
OnMessage(0x204, "OnRDown")
OnMessage(0x232, "OnMoveEnd")
xpos := A_ScreenWidth - CW
ptPosY := Round(32 * ptS)
Gui, Main:Show, x%xpos% y%ptPosY% w%CWu% h%CHu% NoActivate, PPT沙漏-计时
WinMove, ahk_id %hMain%,, %xpos%, %ptPosY%, %CW%, %CH%
WinGetPos, gx, gy, gw, gh, ahk_id %hMain%
if (gx + gw > A_ScreenWidth) {
    nx := A_ScreenWidth - gw - Round(8 * ptS)
    if (nx < 0)
        nx := 0
    WinMove, ahk_id %hMain%,, %nx%, %gy%
    IniWrite, %nx%, %ptIni%, Main, PosX
}
WinSet, Region, 0-0 W%CW% H%CH% R12-12, ahk_id %hMain%
WinSet, Transparent, %ptOpacity%, ahk_id %hMain%
WinSet, ExStyle, +0x20, ahk_id %hMain%
if (ptAutoHide = 1)
    Gui, Main:Hide
Gosub DrawCard
TrayTip, PPT沙漏-已启动, 双击时间条开始计时, 3, 1
SetTimer, PollShow, 250
SetTimer, HoverWatch, 120
Hotkey, %startKey%, DoStart
Hotkey, %stopKey%, DoStop
Hotkey, %quitKey%, DoQuit

return

; ================= drawing =================
RRectPath(x, y, w, h, r) {
    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", p := 0)
    DllCall("gdiplus\GdipAddPathArcI", "ptr", p, "int", x, "int", y, "int", r*2, "int", r*2, "float", 180, "float", 90)
    DllCall("gdiplus\GdipAddPathArcI", "ptr", p, "int", x+w-r*2, "int", y, "int", r*2, "int", r*2, "float", 270, "float", 90)
    DllCall("gdiplus\GdipAddPathArcI", "ptr", p, "int", x+w-r*2, "int", y+h-r*2, "int", r*2, "int", r*2, "float", 0, "float", 90)
    DllCall("gdiplus\GdipAddPathArcI", "ptr", p, "int", x, "int", y+h-r*2, "int", r*2, "int", r*2, "float", 90, "float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "ptr", p)
    return p
}

StateColor() {
    global
    if (ptState = "pause")
        return 0xFF6FA8FF
    if (ptState = "over")
        return ptBlink ? 0xFFFF5D64 : 0xFF521B22
    if (ptPreHit)
        return 0xFFD8B23A
    return 0xFF00E676
}

DrawCard:
ptPreHit := (ptState = "run" && ptPre > 0 && ptRemain <= ptPre*60)
col := StateColor()
DllCall("gdiplus\GdipGraphicsClear", "ptr", gGfx, "uint", 0xFF000000)
rad := Round(12 * ptS)
path := RRectPath(1, 1, CW-2, CH-2, rad)
DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFF000000, "ptr*", br := 0)
DllCall("gdiplus\GdipFillPath", "ptr", gGfx, "ptr", br, "ptr", path)
DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
DllCall("gdiplus\GdipCreatePen1", "uint", 0xFF2E2E2E, "float", 1.0 * ptS, "int", 2, "ptr*", pn := 0)
DllCall("gdiplus\GdipDrawPath", "ptr", gGfx, "ptr", pn, "ptr", path)
DllCall("gdiplus\GdipDeletePen", "ptr", pn)
DllCall("gdiplus\GdipDeletePath", "ptr", path)
led := (ptState = "over") ? ("+" FormatLed(ptOver0)) : FormatLed(ptRemain)
colGhost := (ptState = "pause") ? 0x285AB6FF : (ptState = "over" ? 0x28FF5D64 : 0x2800E676)
if (ptState = "pause")
    colGhost := 0x285AB6FF
if (fLed != 0) {
    VarSetCapacity(rcL, 16, 0)
    NumPut(Round(4*ptS) + 0.0, rcL, 0, "float"), NumPut(Round(4*ptS) + 0.0, rcL, 4, "float")
    NumPut(Round(192*ptS) + 0.0, rcL, 8, "float"), NumPut(Round(68*ptS) + 0.0, rcL, 12, "float")
    DllCall("gdiplus\GdipCreateSolidFill", "uint", colGhost, "ptr*", br)
    DllCall("gdiplus\GdipDrawString", "ptr", gGfx, "wstr", "88:88", "int", -1, "ptr", fLed, "ptr", &rcL, "ptr", sfC, "ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    ledNums := (ptState = "over") ? SubStr(led, 2) : led
    DllCall("gdiplus\GdipCreateSolidFill", "uint", col, "ptr*", br)
    DllCall("gdiplus\GdipDrawString", "ptr", gGfx, "wstr", ledNums, "int", -1, "ptr", fLed, "ptr", &rcL, "ptr", sfC, "ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    if (ptState = "over")
        DrawLedPlus(col)
} else
    DrawLed(led, col, colGhost)
if (ptHover) {
    VarSetCapacity(rcb0, 16, 0)
    NumPut(btnAbtL + 0.0, rcb0, 0, "float"), NumPut(btnT + 0.0, rcb0, 4, "float")
    NumPut((btnAbtR-btnAbtL) + 0.0, rcb0, 8, "float"), NumPut((btnB-btnT) + 0.0, rcb0, 12, "float")
    DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFF00E676, "ptr*", br)
    DllCall("gdiplus\GdipDrawString", "ptr", gGfx, "wstr", "i", "int", -1, "ptr", fBtn, "ptr", &rcb0, "ptr", sfC, "ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    VarSetCapacity(rcb1, 16, 0)
    NumPut(btnSetL + 0.0, rcb1, 0, "float"), NumPut(btnT + 0.0, rcb1, 4, "float")
    NumPut((btnSetR-btnSetL) + 0.0, rcb1, 8, "float"), NumPut((btnB-btnT) + 0.0, rcb1, 12, "float")
    VarSetCapacity(rcb2, 16, 0)
    NumPut(btnExitL + 0.0, rcb2, 0, "float"), NumPut(btnT + 0.0, rcb2, 4, "float")
    NumPut((btnExitR-btnExitL) + 0.0, rcb2, 8, "float"), NumPut((btnB-btnT) + 0.0, rcb2, 12, "float")
    DllCall("gdiplus\GdipCreateSolidFill", "uint", 0xFF00E676, "ptr*", br)
    DllCall("gdiplus\GdipDrawString", "ptr", gGfx, "wstr", "⚙", "int", -1, "ptr", fBtn, "ptr", &rcb1, "ptr", sfC, "ptr", br)
    DllCall("gdiplus\GdipDrawString", "ptr", gGfx, "wstr", "✕", "int", -1, "ptr", fBtn, "ptr", &rcb2, "ptr", sfC, "ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}
hbRc := DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", gBmp, "ptr*", hbm := 0, "uint", 0xFF000000)
oldImg := DllCall("SendMessageW", "ptr", hPic, "uint", 0x0172, "ptr", 0, "ptr", hbm, "ptr")
if (oldImg)
    DllCall("DeleteObject", "ptr", oldImg)
WinSetTitle, ahk_id %hMain%,, PPT沙漏-计时 %led%
return

FormatLed(sec) {
    return Format("{:02d}:{:02d}", sec//60, Mod(sec,60))
}

; ================= mouse =================
OnLDown(w, l, msg, hwnd) {
    global
    if (hwnd != hMain && hwnd != hPic)
        return
    x := l & 0xFFFF, y := l >> 16
    if (ptHover && x >= btnAbtL && x <= btnAbtR && y >= btnT && y <= btnB) {
        SetTimer, DoAbtClick, -1
        return
    }
    if (ptHover && x >= btnSetL && x <= btnSetR && y >= btnT && y <= btnB) {
        SetTimer, DoSetClick, -1
        return
    }
    if (ptHover && x >= btnExitL && x <= btnExitR && y >= btnT && y <= btnB) {
        SetTimer, DoExitClick, -1
        return
    }
    ptDragging := 1
    DllCall("PostMessageW", "ptr", hMain, "uint", 0xA1, "ptr", 2, "ptr", 0)
}
DoSetClick:
Gosub OpenSet
return
DoExitClick:
Gosub DoQuit
return
OnLDbl(w, l, msg, hwnd) {
    global
    if (hwnd != hMain && hwnd != hPic)
        return
    x := l & 0xFFFF, y := l >> 16
    if (x >= btnAbtL - 6 && x <= btnExitR + 6 && y >= btnT - 6 && y <= btnB + 6)
        return
    if (ptState = "idle") {
        Gosub DoStart
        if (!IsSlideShow())
            Gosub StartSlideshow
    }
    else if (ptState = "pause")
        Gosub MenuPause
    else
        Gosub DoStop
}
OnRDown(w, l, msg, hwnd) {
    global
    if (hwnd != hMain && hwnd != hPic)
        return
    Menu, PtMenu, Show
}
GearClick:
Gosub OpenSet
return
OnMoveEnd(w, l, m, hwnd) {
    global
    ptDragging := 0
}

; ================= menu/tray =================
BuildMenu:
Menu, PtMenu, Add, 启动计时, MenuStart
Menu, PtMenu, Add, 停止计时, MenuStop
Menu, PtMenu, Add, 暂停计时, MenuPause
Menu, PtMenu, Add
Menu, PtMenu, Add, 设置…, OpenSet
Menu, PtMenu, Add, 开机自启, MenuAutoRun
Menu, PtMenu, % (ptAutoRun = 1) ? "Check" : "UnCheck", 开机自启
Menu, PtMenu, Add, 关于 幻灯沙漏, OpenAbout
Menu, PtMenu, Add, 退出, DoQuit
Menu, Tray, NoStandard
Menu, Tray, Add, 显示主界面, MenuShow
Menu, Tray, Add
Menu, Tray, Add, 启动计时, MenuStart
Menu, Tray, Add, 停止计时, MenuStop
Menu, Tray, Add, 暂停计时, MenuPause
Menu, Tray, Add
Menu, Tray, Add, 设置…, OpenSet
Menu, Tray, Add, 关于 幻灯沙漏, OpenAbout
Menu, Tray, Add, 退出, DoQuit
Menu, Tray, Default, 显示主界面
Menu, Tray, Tip, PPT沙漏 pptglass
return

; ================= slideshow detect =================
PollShow:
show := IsSlideShow()
if (show && !ptShowOn) {
    ptShowOn := true
    if (ptAutoHide = 1)
        Gui, Main:Show, NoActivate
    if (ptState = "idle")
        Gosub DoStart
} else if (!show && ptShowOn) {
    ptShowOn := false
    if (ptState != "idle")
        Gosub DoStop
    if (ptAutoHide = 1)
        Gui, Main:Hide
}
return

IsSlideShow() {
    global ptShowClasses, ptShowProcs
    Loop, parse, ptShowClasses, `,
    {
        cls := Trim(A_LoopField)
        if (cls = "")
            continue
        IfWinExist, % "ahk_class " cls
            return true
    }
    Loop, parse, ptShowProcs, `,
    {
        proc := Trim(A_LoopField)
        if (proc = "")
            continue
        WinGet, wl, List, % "ahk_exe " proc
        Loop, %wl%
        {
            wid := wl%A_Index%
            WinGet, st, Style, ahk_id %wid%
            WinGet, ex, ExStyle, ahk_id %wid%
            WinGetPos,,, w, h, ahk_id %wid%
            if ((st & 0x10000000) && (ex & 0x8) && w >= A_ScreenWidth*0.9 && h >= A_ScreenHeight*0.9)
                return true
        }
    }
    return false
}

; ================= timer =================
DoStart:
if (ptState = "run")
    return
if (ptState = "idle") {
    ptPrealed := 0
    ptRemain := ptLimit * 60
}
ptState := "run"
SetTimer, Tick, 1000
Gosub Tick
return

DoStop:
SetTimer, Tick, Off
ptState := "idle"
ptRemain := ptLimit * 60
Gui, Pop:Destroy
SetTimer, ClosePop, Off
Gosub DrawCard
return

MenuStart:
Gosub DoStart
return
MenuStop:
Gosub DoStop
return
MenuShow:
Gui, Main:Show
return
MenuPause:
if (ptState = "pause") {
    ptState := (ptRemain = 0) ? "over" : "run"
    SetTimer, Tick, 1000
    Menu, PtMenu, Rename, 继续计时, 暂停计时
    Menu, Tray, Rename, 继续计时, 暂停计时
} else if (ptState = "run" || ptState = "over") {
    ptState := "pause"
    SetTimer, Tick, Off
    Menu, PtMenu, Rename, 暂停计时, 继续计时
    Menu, Tray, Rename, 暂停计时, 继续计时
    Gosub DrawCard
}
return
MenuAutoRun:
ptAutoRun := (ptAutoRun = 1) ? 0 : 1
Menu, PtMenu, % (ptAutoRun = 1) ? "Check" : "UnCheck", 开机自启
Gosub ApplyAutoRun
return
ApplyAutoRun:
if (ptAutoRun = 1)
    RegWrite, REG_SZ, HKCU\Software\Microsoft\Windows\CurrentVersion\Run, PPTTimerNew, "%A_ScriptFullPath%"
else
    RegDelete, HKCU\Software\Microsoft\Windows\CurrentVersion\Run, PPTTimerNew
return

Tick:
if (ptState != "run")
    return
if (ptRemain > 0) {
    if (ptPre > 0 && ptRemain = ptPre*60 && ptPrealed != 1) {
        ptPrealed := 1
        if FileExist(ptPreFile)
            SoundPlay, %ptPreFile%
        Gosub ShowPrePop
    }
    ptRemain--
} else if (ptState != "over") {
    ptState := "over"
    ptOver0 := 1
    if FileExist(ptEndFile)
        SoundPlay, %ptEndFile%
    Gosub ShowOverPop
} else {
    ptOver0++
    ptBlink := !ptBlink
}
Gosub DrawCard
return

; ================= popups =================
ShowPrePop:
Gui, Pop:Destroy
Gui, Pop:New, +AlwaysOnTop +ToolWindow -Caption, PPT沙漏-提示
Gui, Pop:Color, 000000
Gui, Pop:Font, s12 Bold c00E676, Microsoft YaHei UI
Gui, Pop:Add, Text, x18 y14 w244 vpopTxt Center, 还剩 %ptPre% 分钟
Gui, Pop:Show, NoActivate
Gui, Pop:+LastFound
WinSet, Trans, 242
SetTimer, ClosePop, -6000
return

ShowOverPop:
Gui, Pop:Destroy
Gui, Pop:New, +AlwaysOnTop +ToolWindow -Caption, PPT沙漏-提示
Gui, Pop:Color, 0A0A0A
Gui, Pop:Font, s12 Bold cFF8A86, Microsoft YaHei UI
Gui, Pop:Add, Text, x18 y14 w280 vpopTxt Center, %ptMsg%
Gui, Pop:Show, NoActivate
Gui, Pop:+LastFound
WinSet, Trans, 246
return

ClosePop:
SetTimer, ClosePop, Off
Gui, Pop:Destroy
return

PopGuiClose:
Gosub ClosePop
return

; ================= settings =================
OpenSet:
ckHideOpt := (ptAutoHide = 1) ? "Checked" : ""
ckRunOpt := (ptAutoRun = 1) ? "Checked" : ""
Gui, Set:New, +AlwaysOnTop, PPT沙漏-设置
Gui, Set:Font, s10 c202020, Microsoft YaHei UI
Gui, Set:Add, Text, x18 y20, 限时（分钟）
Gui, Set:Add, Edit, x130 y16 w56 veditLimit Number Center, %ptLimit%
Gui, Set:Add, UpDown, Range1-99, %ptLimit%
Gui, Set:Add, Text, x210 y20, 预铃（分钟）
Gui, Set:Add, Edit, x300 y16 w46 veditPre Number Center, %ptPre%
Gui, Set:Add, UpDown, Range0-30, %ptPre%
Gui, Set:Add, Text, x18 y54, 音量
Gui, Set:Add, Slider, x130 y48 w460 h26 NoTicks Line10 veditVol gOnVolLive cC9A227, %ptVol%
Gui, Set:Add, Text, x18 y88, 预铃声音
Gui, Set:Add, Edit, x130 y84 w480 veditPreFile, %ptPreFile%
Gui, Set:Add, Text, x18 y120, 结束声音
Gui, Set:Add, Edit, x130 y116 w480 veditEndFile, %ptEndFile%
Gui, Set:Add, Text, x18 y152, 超时提示语
Gui, Set:Add, Edit, x130 y148 w480 veditMsg, %ptMsg%
Gui, Set:Add, Checkbox, x18 y186 vckAutoHide %ckHideOpt%, 自动隐藏（仅放映时显示）
Gui, Set:Add, Checkbox, x18 y212 vckAutoRun %ckRunOpt%, 开机自动启动
Gui, Set:Font, s10 Bold c00695C, Microsoft YaHei UI
Gui, Set:Add, Button, x18 y246 w96 gTestPre, 试听预铃
Gui, Set:Add, Button, x124 y246 w96 gTestEnd, 试听结束
Gui, Set:Add, Button, x502 y246 w108 gSaveSet Default, 保存并关闭
Gui, Set:Show,, PPT沙漏-设置
return

OnVolLive:
GuiControlGet, vv2, Set:, editVol
if (vv2 != "")
    SoundSet, %vv2%, Wave
return

TestPre:
GuiControlGet, tf, Set:, editPreFile
if (tf = "")
    tf := ptPreFile
if FileExist(tf)
    SoundPlay, %tf%
else
    TrayTip, PPT沙漏-提示, 声音文件不存在：%tf%, 2, 2
return
TestEnd:
GuiControlGet, tf, Set:, editEndFile
if (tf = "")
    tf := ptEndFile
if FileExist(tf)
    SoundPlay, %tf%
else
    TrayTip, PPT沙漏-提示, 声音文件不存在：%tf%, 2, 2
return
SaveSet:
GuiControlGet, lv, Set:, editLimit
GuiControlGet, pv, Set:, editPre
GuiControlGet, vv, Set:, editVol
GuiControlGet, edPreFile, Set:, editPreFile
GuiControlGet, edEndFile, Set:, editEndFile
GuiControlGet, edMsg, Set:, editMsg
GuiControlGet, ckAutoHide, Set:, ckAutoHide
GuiControlGet, ckAutoRun, Set:, ckAutoRun
if (lv = "" || lv + 0 < 1)
    lv := 1
if (lv + 0 > 99)
    lv := 99
if (pv = "")
    pv := 0
ptLimit := lv + 0
ptPre := pv + 0
ptVol := vv
ptPreFile := edPreFile, ptEndFile := edEndFile, ptMsg := edMsg
ptAutoHide := ckAutoHide, ptAutoRun := ckAutoRun
if (ptState = "idle")
    ptRemain := ptLimit * 60
SoundSet, %ptVol%, Wave
Menu, PtMenu, % (ptAutoRun = 1) ? "Check" : "UnCheck", 开机自启
Gosub ApplyAutoRun
Gosub SaveIni
Gui, Set:Destroy
Gosub DrawCard
return
SetGuiClose:
Gui, Set:Destroy
return

DoQuit:
Gosub SaveIni
SoundSet, %ptVol0%, Wave
ExitApp
return

SaveIni:
IniWrite, 0, %ptIni%, Main, LimitHour
IniWrite, %ptLimit%, %ptIni%, Main, LimitMin
IniWrite, %ptPre%, %ptIni%, Main, PreAlarm
IniWrite, %ptVol%, %ptIni%, Main, Volume
IniWrite, %ptOpacity%, %ptIni%, Main, Opacity
IniWrite, %ptPreFile%, %ptIni%, Main, PreAlarmFile
IniWrite, %ptEndFile%, %ptIni%, Main, EndAlarmFile
IniWrite, %ptMsg%, %ptIni%, Main, TimeoutMsg
IniWrite, %ptAutoHide%, %ptIni%, Main, AutoHide
IniWrite, %ptAutoRun%, %ptIni%, Main, AutoRun
return

HoverWatch:
if (!hMain)
    return
CoordMode, Mouse, Screen
MouseGetPos, mx, my
WinGetPos, wx, wy, ww, wh, ahk_id %hMain%
over := (mx >= wx && mx < wx + ww && my >= wy && my < wy + wh)
if (over != ptHover) {
    ptHover := over
    if (over)
        WinSet, ExStyle, -0x20, ahk_id %hMain%
    else
        WinSet, ExStyle, +0x20, ahk_id %hMain%
    Gosub DrawCard
}
return

StartSlideshow:
try {
    pp := ComObjActive("PowerPoint.Application")
    pp.ActivePresentation.SlideShowSettings.Run()
    return
}
try {
    wpp := ComObjActive("KWPP.Application")
    wpp.ActivePresentation.SlideShowSettings.Run()
    return
}
TrayTip, PPT沙漏-已开始计时, 未检测到播放器，请先启动 PowerPoint 或 WPS…, 4, 2
return


; ============ seven-segment LED ============
SegFill(px, py, pw, ph, col) {
    global gGfx
    if (pw < 1 || ph < 1)
        return
    r := (ph < pw) ? Round(ph/2) : Round(pw/2)
    p := RRectPath(Round(px), Round(py), Round(pw), Round(ph), r)
    DllCall("gdiplus\GdipCreateSolidFill", "uint", col, "ptr*", br := 0)
    DllCall("gdiplus\GdipFillPath", "ptr", gGfx, "ptr", br, "ptr", p)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    DllCall("gdiplus\GdipDeletePath", "ptr", p)
}

DrawSeg(seg, x, y, w, h, t, col) {
    if (seg = "a")
        SegFill(x + t*1.35, y, w - t*2.7, t, col)
    else if (seg = "g")
        SegFill(x + t*1.35, y + (h-t)/2, w - t*2.7, t, col)
    else if (seg = "d")
        SegFill(x + t*1.35, y + h - t, w - t*2.7, t, col)
    else if (seg = "f")
        SegFill(x, y + t*1.1, t, h/2 - t*1.7, col)
    else if (seg = "b")
        SegFill(x + w - t, y + t*1.1, t, h/2 - t*1.7, col)
    else if (seg = "e")
        SegFill(x, y + h/2 + t*0.6, t, h/2 - t*1.7, col)
    else if (seg = "c")
        SegFill(x + w - t, y + h/2 + t*0.6, t, h/2 - t*1.7, col)
}

DrawDigit(dch, x, y, w, h, t, lit, ghost) {
    static maps := {"0":"abcdef","1":"bc","2":"abgde","3":"abgcd","4":"fgbc","5":"afgcd","6":"afgcde","7":"abc","8":"abcdefg","9":"abcdfg"}
    m := maps[dch]
    Loop, parse, abcdefg
    {
        s := A_LoopField
        on := InStr(m, s) ? lit : ghost
        DrawSeg(s, x, y, w, h, t, on)
    }
}

DrawLed(str, lit, ghost) {
    global CW, CH, ptS, ptState
    dw := 30 * ptS, dh := 46 * ptS, dt := 6.5 * ptS
    gx := 6 * ptS, cwid := 10 * ptS
    n := StrLen(str)
    total := n*dw + (n-1)*gx
    ; colon inside one glyph slot for "MM:SS": treat ":" as slot too
    x0 := (CW - total) / 2
    y0 := (CH - dh) / 2 - 2*ptS
    colonOn := (ptState != "run") ? 1 : Mod(A_Sec, 2)
    Loop, parse, str
    {
        ch := A_LoopField
        if (ch = ":") {
            cx := x0 + cwid/2 - dt/2
            cy1 := y0 + dh*0.28
            cy2 := y0 + dh*0.62
            SegFill(cx, cy1, dt, dt, colonOn ? lit : ghost)
            SegFill(cx, cy2, dt, dt, colonOn ? lit : ghost)
            x0 += cwid + gx
        } else if (ch = "+") {
            SegFill(x0 + dw*0.2, y0 + dh/2 - dt/2, dw*0.6, dt, lit)
            SegFill(x0 + dw/2 - dt/2, y0 + dh*0.3, dt, dh*0.4, lit)
            x0 += dw + gx
        } else {
            DrawDigit(ch, x0, y0, dw, dh, dt, lit, ghost)
            x0 += dw + gx
        }
    }
}

DrawLedPlus(lit) {
    global CW, CH, ptS
    dt := 7 * ptS
    x := Round(14 * ptS)
    y := (CH - Round(40*ptS)) / 2 + Round(20*ptS)
    SegFill(x, y - dt/2, Round(16*ptS), dt, lit)
    SegFill(x + Round(8*ptS) - dt/2, y - Round(10*ptS), dt, Round(20*ptS), lit)
}

DoAbtClick:
Gosub OpenAbout
return

OpenAbout:
Gui, Abt:New, +AlwaysOnTop, PPT沙漏-关于
Gui, Abt:Font, s11 Bold c202020, Microsoft YaHei UI
Gui, Abt:Add, Text, x24 y22 w340, 版本 1.0.0（2026）· PPT / WPS 放映计时器
Gui, Abt:Font, s10 c404040, Microsoft YaHei UI
Gui, Abt:Add, Text, x24 y52 w340, 双击时间条：开始计时并启动放映
Gui, Abt:Font, s9 c707070, Microsoft YaHei UI
Gui, Abt:Add, Text, x24 y84 w340, 界面字体：DSEG7 Classic（SIL OFL 1.1）
Gui, Abt:Add, Text, x24 y104 w340, Copyright (c) 2026 pptglass
Gui, Abt:Font, s10 Bold, Microsoft YaHei UI
Gui, Abt:Add, Button, x270 y134 w96 gAbtOk Default, 确定
Gui, Abt:Show,, PPT沙漏-关于
return
AbtOk:
AbtGuiClose:
Gui, Abt:Destroy
return
Gui, Abt:Destroy
return
