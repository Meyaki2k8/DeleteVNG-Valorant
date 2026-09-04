#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; --- Administrator Privilege Elevation & Warning UI ---
if !A_IsAdmin {
    try {
        if A_IsCompiled
            Run '*RunAs "' A_ScriptFullPath '"'
        else
            Run '*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"'
        ExitApp
    } catch {
        adminDlg := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", "Administrator Rights Required")
        adminDlg.SetFont("s10 bold cE11D48", "Segoe UI")
        adminDlg.Add("Text", "x20 y15 w360 h25", "⚠️ Administrator Privileges Required")
        
        adminDlg.SetFont("s9 c374151", "Segoe UI")
        adminDlg.Add("Text", "x20 y45 w360 h45", "Valorant Tool requires Admin rights to modify files in the Riot Games directory.\n\nPlease restart by right-clicking the app and selecting 'Run as administrator'.")
        
        btnOk := adminDlg.Add("Button", "x150 y100 w100 h30 Default", "OK")
        btnOk.OnEvent("Click", (*) => ExitApp())
        adminDlg.OnEvent("Close", (*) => ExitApp())
        
        adminDlg.Show("w400 h145")
        Pause
    }
}

; --- Application Metadata & Registry Configuration ---
global AppVersion := "1.0"
global UpdateUrl := "https://raw.githubusercontent.com/Meyaki2k8/DeleteVNG-Valorant/main/version.json"
global ReleaseUrl := "https://github.com/Meyaki2k8/DeleteVNG-Valorant/releases"

global AppName := "DeleteVNGValorant"
global AppRegKey := "HKCU\Software\" AppName
global StartupRegKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"

global DefaultPaks := "C:\Riot Games\VALORANT\live\ShooterGame\Content\Paks"
global ValorantProcess := "VALORANT-Win64-Shipping.exe"

global TargetFiles := [
    "VNGLogo-WindowsClient.pak",
    "VNGLogo-WindowsClient.sig",
    "VNGLogo-WindowsClient.ucas",
    "VNGLogo-WindowsClient.utoc"
]

; --- Global State & Controls Declaration ---
global isBusy := false
global hasExecuted := false
global isUpdating := false
defaultTheme := IsSystemDarkMode() ? 1 : 2

global PaksPath := Trim(RegReadSafe(AppRegKey, "PaksPath", DefaultPaks))
global DelaySec := Max(0, Integer(RegReadSafe(AppRegKey, "DelaySec", 0)))
global MinimizeTray := Integer(RegReadSafe(AppRegKey, "MinimizeToTray", 1))
global ThemeMode := Integer(RegReadSafe(AppRegKey, "ThemeMode", defaultTheme))
global StartupEnabled := CheckStartup()

global C := MatrixColors(ThemeMode == 1)
global lastHwnd := 0
global HoverMap := Map()

global MyGui, PathEdit, DelayEdit, MinimizeBtn, StartupBtn, BrowseBtn, FileCountText, FileStateText, PathStateText, DummyFocus, StatusDot
global BtnMin, BtnClose, BtnTheme, Panel1, Panel2, Panel3, Label1, Label2, Label3, HeaderTitle, VersionTag, DelayLbl1, DelayLbl2, DelayRec

; --- Initialize Application GUI ---
BuildUI()
BuildTray()
RegisterHoverControls()
RefreshUI()

MyGui.Show("w500 h360")
ApplyRoundedCorners()
ApplyTextPadding()
DeselectPathText()

; --- Timers & Message Handlers ---
OnMessage(0x0201, WM_LBUTTONDOWN)
OnMessage(0x0200, WM_MOUSEMOVE)
SetTimer(WatchGame, 1000)
SetTimer(CheckForUpdates, -3000)

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global MyGui
    if (hwnd = MyGui.Hwnd)
        PostMessage(0xA1, 2,,, "ahk_id " MyGui.Hwnd)
}

WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global lastHwnd, HoverMap, C, MinimizeTray, StartupEnabled
    static hHand := 0
    if !hHand
        hHand := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr")

    if (hwnd == lastHwnd)
        return

    if (lastHwnd) {
        ResetControlBg(lastHwnd)
        lastHwnd := 0
    }

    if HoverMap.Has(hwnd) {
        DllCall("SetCursor", "Ptr", hHand)
        item := HoverMap[hwnd]
        
        switch item.type {
            case "close":
                item.ctrl.Opt("Background" C.DANGER)
            case "toggle_min":
                item.ctrl.Opt("Background" (MinimizeTray ? C.ACTIVE_BG : C.HOVER))
            case "toggle_start":
                item.ctrl.Opt("Background" (StartupEnabled ? C.ACTIVE_BG : C.HOVER))
            case "browse":
                item.ctrl.Opt("Background" C.ACCENT_HOVER)
            default:
                item.ctrl.Opt("Background" C.HOVER)
        }
        lastHwnd := hwnd
        SetTimer(CheckHoverLeave, 50)
    }
}

; Kiểm tra và reset hover chuẩn xác bằng Mode 1 (Control HWND)
CheckHoverLeave() {
    global lastHwnd
    if !lastHwnd {
        SetTimer(CheckHoverLeave, 0)
        return
    }
    MouseGetPos(,,, &currHwnd, 1) ; Sửa Mode 2 -> 1 để lấy HWND của Control
    if (currHwnd != lastHwnd) {
        ResetControlBg(lastHwnd)
        lastHwnd := 0
        SetTimer(CheckHoverLeave, 0)
    }
}

ResetControlBg(hwnd) {
    global HoverMap, C, MinimizeTray, StartupEnabled
    if !HoverMap.Has(hwnd)
        return
    
    item := HoverMap[hwnd]
    switch item.type {
        case "normal", "close": 
            item.ctrl.Opt("Background" C.BG)
        case "browse": 
            item.ctrl.Opt("Background" C.ACCENT)
        case "toggle_min": 
            RenderToggle(item.ctrl, MinimizeTray, "Minimize to tray")
        case "toggle_start": 
            RenderToggle(item.ctrl, StartupEnabled, "Start with Windows")
    }
}

RegisterHoverControls() {
    global HoverMap, BtnMin, BtnClose, BtnTheme, BrowseBtn, MinimizeBtn, StartupBtn
    HoverMap := Map(
        BtnMin.Hwnd,      { ctrl: BtnMin,      type: "normal" },
        BtnClose.Hwnd,    { ctrl: BtnClose,    type: "close" },
        BtnTheme.Hwnd,    { ctrl: BtnTheme,    type: "normal" },
        BrowseBtn.Hwnd,   { ctrl: BrowseBtn,   type: "browse" },
        MinimizeBtn.Hwnd, { ctrl: MinimizeBtn, type: "toggle_min" },
        StartupBtn.Hwnd,  { ctrl: StartupBtn,  type: "toggle_start" }
    )
}

MinimizeApp(*) {
    global BtnMin, lastHwnd, MyGui
    ResetControlBg(BtnMin.Hwnd)
    lastHwnd := 0
    MyGui.Minimize()
}

; --- Main Interface Construction ---
BuildUI() {
    global MyGui, PathEdit, DelayEdit, MinimizeBtn, StartupBtn, BrowseBtn, FileCountText, FileStateText, PathStateText, DummyFocus, StatusDot
    global BtnMin, BtnClose, BtnTheme, C, ThemeMode, Panel1, Panel2, Panel3, Label1, Label2, Label3, HeaderTitle, VersionTag, DelayLbl1, DelayLbl2, DelayRec
    global PaksPath, DelaySec, MinimizeTray, StartupEnabled

    MyGui := Gui("-Caption -Border +MinimizeBox", "Valorant Tool")
    MyGui.BackColor := C.BG
    MyGui.MarginX := MyGui.MarginY := 0
    MyGui.OnEvent("Close", (*) => OnClose())

    DummyFocus := MyGui.Add("Button", "x-100 y-100 w1 h1", "")

    ; Status Dot
    StatusDot := MyGui.Add("Text", "x16 y10 w16 h20 BackgroundTrans c" C.SUCCESS, "●")
    StatusDot.SetFont("s12", "Segoe UI")

    ; Header Section
    MyGui.SetFont("s10 bold c" C.TEXT, "Segoe UI")
    HeaderTitle := MyGui.Add("Text", "x34 y10 w150 h24 BackgroundTrans", "Valorant Tool")
    
    MyGui.SetFont("s8 bold c" C.ACCENT, "Segoe UI")
    VersionTag := MyGui.Add("Text", "x184 y12 w60 h20 BackgroundTrans", "v" AppVersion)

    BtnTheme := MyGui.Add("Text", "x330 y6 w80 h28 Background" C.BG " c" C.MUTED " Center +0x200", ThemeMode == 1 ? "🌙 Dark" : "☀️ Light")
    BtnMin := MyGui.Add("Text", "x420 y6 w32 h28 Background" C.BG " c" C.MUTED " Center +0x200", "—")
    BtnClose := MyGui.Add("Text", "x456 y6 w38 h28 Background" C.BG " c" C.MUTED " Center +0x200", "✕")
    
    BtnTheme.SetFont("s8 bold", "Segoe UI")
    BtnMin.SetFont("s10 bold", "Segoe UI")
    BtnClose.SetFont("s10 bold", "Segoe UI")
    
    BtnTheme.OnEvent("Click", CycleTheme)
    BtnMin.OnEvent("Click", MinimizeApp)
    BtnClose.OnEvent("Click", (*) => OnClose())

    ; Section 1: Directory Setup
    Label1 := Label("GAME DIRECTORY", 20, 42)
    Panel1 := MyGui.Add("Text", "x20 y60 w460 h78 Background" C.PANEL)

    MyGui.SetFont("s9 c" C.TEXT, "Segoe UI")
    PathEdit := MyGui.Add("Text", "x32 y72 w326 h26 Background" C.INPUT " c" C.TEXT " +0x200", PaksPath)

    BrowseBtn := ButtonText("Browse", 368, 72, 100, 26, C.ACCENT, "FFFFFF")
    BrowseBtn.OnEvent("Click", SelectFolder)

    MyGui.SetFont("s8 c" C.MUTED, "Segoe UI")
    PathStateText := MyGui.Add("Text", "x32 y106 w430 h18 BackgroundTrans", "")

    ; Section 2: Automation Controls
    Label2 := Label("AUTOMATION", 20, 150)
    Panel2 := MyGui.Add("Text", "x20 y168 w460 h86 Background" C.PANEL)

    MyGui.SetFont("s9 c" C.MUTED, "Segoe UI")
    DelayLbl1 := MyGui.Add("Text", "x32 y182 w90 h26 BackgroundTrans +0x200", "Launch delay:")

    DelayEdit := MyGui.Add("Edit", "x125 y182 w50 h26 Background" C.INPUT " c" C.TEXT " Number -E0x200 -Border Center +Multi -VScroll -HScroll -Wrap -WantReturn", DelaySec)
    DelayEdit.OnEvent("Change", (*) => SaveSettings())

    MyGui.SetFont("s8 c" C.MUTED, "Segoe UI")
    DelayLbl2 := MyGui.Add("Text", "x182 y182 w50 h26 BackgroundTrans +0x200", "seconds")

    MyGui.SetFont("s8 bold c" C.ACCENT, "Segoe UI")
    DelayRec := MyGui.Add("Text", "x250 y182 w210 h26 BackgroundTrans Right +0x200", "Recommended: 0s")

    MinimizeBtn := MyGui.Add("Text", "x32 y216 w208 h28 Center +0x200", "")
    StartupBtn := MyGui.Add("Text", "x252 y216 w216 h28 Center +0x200", "")

    RenderToggle(MinimizeBtn, MinimizeTray, "Minimize to tray")
    RenderToggle(StartupBtn, StartupEnabled, "Start with Windows")

    MinimizeBtn.OnEvent("Click", ToggleMinimize)
    StartupBtn.OnEvent("Click", ToggleStartup)

    ; Section 3: File Monitoring
    Label3 := Label("VNG LOGO FILES", 20, 266)
    Panel3 := MyGui.Add("Text", "x20 y284 w460 h60 Background" C.PANEL)

    MyGui.SetFont("s14 bold c" C.TEXT, "Segoe UI")
    FileCountText := MyGui.Add("Text", "x32 y300 w70 h28 BackgroundTrans +0x200", "0 / 4")

    MyGui.SetFont("s8 c" C.MUTED, "Segoe UI")
    FileStateText := MyGui.Add("Text", "x105 y300 w340 h28 BackgroundTrans +0x200", "Checking...")
}

; --- UI Dynamic Theme Switcher ---
CycleTheme(*) {
    global ThemeMode, AppRegKey, C, MyGui, Panel1, Panel2, Panel3, BtnTheme, BtnMin, BtnClose
    global HeaderTitle, VersionTag, Label1, Label2, Label3, DelayLbl1, DelayLbl2, DelayRec
    global PathEdit, DelayEdit, BrowseBtn, MinimizeBtn, StartupBtn, MinimizeTray, StartupEnabled

    clipBackup := ClipboardAll()

    ThemeMode := (ThemeMode == 1) ? 2 : 1
    
    try RegWrite(ThemeMode, "REG_DWORD", AppRegKey, "ThemeMode")
    C := MatrixColors(ThemeMode == 1)

    DllCall("SendMessage", "Ptr", MyGui.Hwnd, "UInt", 0x000B, "Ptr", 0, "Ptr", 0)

    MyGui.BackColor := C.BG
    Panel1.Opt("Background" C.PANEL)
    Panel2.Opt("Background" C.PANEL)
    Panel3.Opt("Background" C.PANEL)

    BtnTheme.Text := (ThemeMode == 1 ? "🌙 Dark" : "☀️ Light")
    BtnTheme.Opt("Background" C.BG " c" C.MUTED)
    BtnMin.Opt("Background" C.BG " c" C.MUTED)
    BtnClose.Opt("Background" C.BG " c" C.MUTED)
    HeaderTitle.Opt("c" C.TEXT)
    VersionTag.Opt("c" C.ACCENT)

    Label1.Opt("c" C.MUTED)
    Label2.Opt("c" C.MUTED)
    Label3.Opt("c" C.MUTED)
    DelayLbl1.Opt("c" C.MUTED)
    DelayLbl2.Opt("c" C.MUTED)
    DelayRec.Opt("c" C.ACCENT)

    PathEdit.Opt("Background" C.INPUT " c" C.TEXT)
    DelayEdit.Opt("Background" C.INPUT " c" C.TEXT)
    BrowseBtn.Opt("Background" C.ACCENT " cFFFFFF")

    RenderToggle(MinimizeBtn, MinimizeTray, "Minimize to tray")
    RenderToggle(StartupBtn, StartupEnabled, "Start with Windows")
    RefreshUI()

    DllCall("SendMessage", "Ptr", MyGui.Hwnd, "UInt", 0x000B, "Ptr", 1, "Ptr", 0)
    WinRedraw(MyGui.Hwnd)

    SetTimer(() => (A_Clipboard := clipBackup), -50)
}

; --- Automation & File Operations ---
WatchGame(*) {
    global isBusy, hasExecuted, ValorantProcess, DelaySec, StatusDot, C
    if isBusy
        return

    if ProcessExist(ValorantProcess) {
        isBusy := true
        hasExecuted := false ; Reset trạng thái chưa thực thi hành động xóa
        StatusDot.Opt("c" C.WARNING)
        if (DelaySec > 0)
            SetTimer(ExecuteGameAction, -DelaySec * 1000)
        else
            ExecuteGameAction()
    } else {
        StatusDot.Opt("c" C.SUCCESS)
    }
}

ExecuteGameAction() {
    global hasExecuted
    try {
        hasExecuted := true ; Đánh dấu đã thực thi hành động thành công
        ProcessFiles()
        RefreshUI()
    } finally {
        SetTimer(WaitGameExit, 1000)
    }
}

WaitGameExit() {
    global ValorantProcess, isBusy, hasExecuted, StatusDot, C
    if !ProcessExist(ValorantProcess) {
        SetTimer(WaitGameExit, 0)
        isBusy := false
        hasExecuted := false
        StatusDot.Opt("c" C.SUCCESS)
        RefreshUI()
    }
}

ProcessFiles() {
    global PaksPath, TargetFiles
    failedFiles := []
    
    for Name in TargetFiles {
        File := PaksPath "\" Name
        if FileExist(File) {
            try FileDelete(File)
            catch {
                failedFiles.Push(Name)
            }
        }
    }

    if failedFiles.Length > 0
        ShowToast("Could not delete: " Join(failedFiles, ", "), "VNG Cleaner Warning")
    else
        ShowToast("VNG logo files cleaned successfully!", "Valorant Tool")
}

; --- GitHub Non-Blocking Robust Auto Updater ---
CheckForUpdates(*) {
    global UpdateUrl, isUpdating, AppVersion
    if isUpdating
        return
        
    isUpdating := true
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(2000, 2000, 2000, 5000)
        req.Open("GET", UpdateUrl "?t=" A_TickCount, true)
        
        req.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ValorantTool/" AppVersion)
        req.SetRequestHeader("Cache-Control", "no-cache, no-store, must-revalidate")
        req.SetRequestHeader("Pragma", "no-cache")
        
        req.Send()
        SetTimer(() => CheckUpdateAsync(req), -500)
    } catch {
        isUpdating := false
    }
}

CheckUpdateAsync(req) {
    global AppVersion, ReleaseUrl, isUpdating
    try {
        if !req.WaitForResponse(5) {
            return
        }
        if (req.Status == 200) {
            if RegExMatch(req.ResponseText, '"version"\s*:\s*"([^"]+)"', &match) {
                if (VerCompare(match[1], AppVersion) > 0) {
                    if MsgBox("Phiên bản mới (v" match[1] ") đã có sẵn!\nBạn có muốn mở trang GitHub Release để tải về không?", "Cập nhật ứng dụng", "YesNo Iconi") = "Yes"
                        Run(ReleaseUrl)
                }
            }
        }
    } catch {
        ; Silent fail on network error
    } finally {
        isUpdating := false
    }
}

VerCompare(v1, v2) {
    a1 := StrSplit(v1, "."), a2 := StrSplit(v2, ".")
    Loop Max(a1.Length, a2.Length) {
        n1 := a1.Has(A_Index) ? Integer(a1[A_Index]) : 0
        n2 := a2.Has(A_Index) ? Integer(a2[A_Index]) : 0
        if (n1 != n2)
            return n1 > n2 ? 1 : -1
    }
    return 0
}

; --- System Helpers & Utilities ---
ShowToast(Msg, Title := "Valorant Tool") => TrayTip(Msg, Title, "Iconi Mute")

IsSystemDarkMode() {
    try return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") == 0
    return true
}

MatrixColors(isDark) {
    return isDark 
        ? { BG: "0x0B0E14", PANEL: "0x131722", INPUT: "0x1A202C", HOVER: "0x2D3748", ACTIVE_BG: "0x3D1F2D", ACCENT: "0xFF4655", ACCENT_HOVER: "0xE03E4D", TEXT: "0xFFFFFF", MUTED: "0x718096", SUCCESS: "0x10B981", WARNING: "0xF59E0B", DANGER: "0xE11D48" }
        : { BG: "0xF8FAFC", PANEL: "0xFFFFFF", INPUT: "0xEDF2F7", HOVER: "0xE2E8F0", ACTIVE_BG: "0xFCE7F3", ACCENT: "0xFF4655", ACCENT_HOVER: "0xE03E4D", TEXT: "0x1A202C", MUTED: "0x718096", SUCCESS: "0x059669", WARNING: "0xD97706", DANGER: "0xE11D48" }
}

Join(arr, delim := ", ") {
    str := ""
    for idx, val in arr
        str .= (idx = 1 ? "" : delim) val
    return str
}

ApplyTextPadding() {
    global DelayEdit
    SetEditPadding(DelayEdit, 4)
}

SetEditPadding(Ctrl, TopPad := 4) {
    rc := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", Ctrl.Hwnd, "Ptr", rc)
    NumPut("int", TopPad, rc, 4)
    SendMessage(0x00B3, 0, rc.Ptr, Ctrl.Hwnd)
}

DeselectPathText() {
    global DummyFocus
    try DummyFocus.Focus()
}

OnClose(*) {
    global MinimizeTray, MyGui, lastHwnd
    lastHwnd := 0
    MinimizeTray ? MyGui.Hide() : ExitApp()
}

ShowUI(*) {
    global lastHwnd, BtnMin, BtnClose, BtnTheme, BrowseBtn, MinimizeBtn, StartupBtn, MyGui
    lastHwnd := 0
    ResetControlBg(BtnMin.Hwnd)
    ResetControlBg(BtnClose.Hwnd)
    ResetControlBg(BtnTheme.Hwnd)
    ResetControlBg(BrowseBtn.Hwnd)
    ResetControlBg(MinimizeBtn.Hwnd)
    ResetControlBg(StartupBtn.Hwnd)
    RefreshUI()
    MyGui.Show()
    ApplyTextPadding()
    DeselectPathText()
}

RegReadSafe(Key, ValueName, Default) {
    try return RegRead(Key, ValueName)
    return Default
}

SaveSettings(*) {
    global AppRegKey, PathEdit, DelayEdit, MinimizeTray, DelaySec, isBusy, hasExecuted
    try {
        RegWrite(Trim(PathEdit.Text), "REG_SZ", AppRegKey, "PaksPath")
        
        newDelay := Max(0, Integer(Trim(DelayEdit.Value) || 0))
        RegWrite(newDelay, "REG_DWORD", AppRegKey, "DelaySec")
        
        ; Chỉ cập nhật Timer thời gian thực nếu đang bận VÀ CHƯA THỰC THI xóa file
        if (isBusy && !hasExecuted && newDelay != DelaySec) {
            DelaySec := newDelay
            if (DelaySec > 0)
                SetTimer(ExecuteGameAction, -DelaySec * 1000)
            else
                ExecuteGameAction()
        } else {
            DelaySec := newDelay
        }

        RegWrite(MinimizeTray, "REG_DWORD", AppRegKey, "MinimizeToTray")
    } catch as Err {
        ShowToast("Không thể lưu cài đặt Registry: " Err.Message, "Lỗi Registry")
    }
}

ApplyRoundedCorners() {
    global MyGui
    WinSetRegion("0-0 w500 h360 r12-12", "ahk_id " MyGui.Hwnd)
}

RenderToggle(Ctrl, IsChecked, LabelText) {
    global C
    Ctrl.Opt("Background" (IsChecked ? C.ACTIVE_BG : C.INPUT))
    Ctrl.SetFont(IsChecked ? "s8 bold c" C.ACCENT : "s8 c" C.MUTED, "Segoe UI")
    Ctrl.Text := (IsChecked ? "✓  " : "✕  ") LabelText
}

ToggleMinimize(*) {
    global MinimizeTray, MinimizeBtn
    MinimizeTray := !MinimizeTray
    RenderToggle(MinimizeBtn, MinimizeTray, "Minimize to tray")
    SaveSettings()
}

ToggleStartup(*) {
    global StartupRegKey, AppName, StartupEnabled, StartupBtn
    try {
        if !StartupEnabled {
            Target := A_IsCompiled ? '"' A_ScriptFullPath '"' : '"' A_AhkPath '" "' A_ScriptFullPath '"'
            RegWrite(Target, "REG_SZ", StartupRegKey, AppName)
            StartupEnabled := true
        } else {
            RegDelete(StartupRegKey, AppName)
            StartupEnabled := false
        }
        RenderToggle(StartupBtn, StartupEnabled, "Start with Windows")
    } catch as Err {
        ShowToast(Err.Message, "Startup Error")
    }
}

ButtonText(Text, X, Y, W, H, Bg, FontColor) {
    global MyGui
    colorHex := InStr(FontColor, "0x") ? FontColor : "0x" FontColor
    MyGui.SetFont("s8 bold c" colorHex, "Segoe UI")
    return MyGui.Add("Text", "x" X " y" Y " w" W " h" H " Background" Bg " Center +0x200", Text)
}

Label(Text, X, Y) {
    global MyGui, C
    MyGui.SetFont("s8 bold c" C.MUTED, "Segoe UI")
    return MyGui.Add("Text", "x" X " y" Y " w460 h16 BackgroundTrans", Text)
}

RefreshUI(*) {
    global PaksPath, TargetFiles, PathEdit, PathStateText, FileCountText, FileStateText, C
    Path := Trim(PathEdit.Text)

    if !DirExist(Path) {
        PathStateText.Text := "Paks folder not found."
        PathStateText.Opt("c" C.ACCENT)
        FileCountText.Text := "0 / 4"
        FileCountText.Opt("c" C.TEXT)
        FileStateText.Text := "Invalid folder"
        FileStateText.Opt("c" C.ACCENT)
        return
    }

    PathStateText.Text := "Paks folder valid."
    PathStateText.Opt("c" C.SUCCESS)

    Count := 0
    for Name in TargetFiles {
        if FileExist(Path "\" Name)
            Count++
    }

    FileCountText.Text := Count " / 4"
    FileCountText.Opt("c" C.TEXT)
    FileStateText.Text := Count = 4 ? "Target files present" : Count ? "Partial files present" : "No VNG files (Clean)"
    FileStateText.Opt(Count ? "c" C.WARNING : "c" C.SUCCESS)
}

SelectFolder(*) {
    global PathEdit, PaksPath, MyGui
    MyGui.Opt("+OwnDialogs")
    Selected := FileSelect("D", PaksPath, "Select Folder")
    if Selected != "" {
        PaksPath := RegExReplace(Selected, "\\$")
        PathEdit.Text := PaksPath
        SaveSettings()
        RefreshUI()
        ApplyTextPadding()
        DeselectPathText()
    }
}

CheckStartup() {
    global StartupRegKey, AppName
    try {
        RegRead(StartupRegKey, AppName)
        return true
    }
    return false
}

BuildTray() {
    global Tray
    A_IconTip := "Valorant Tool v" AppVersion
    Tray := A_TrayMenu
    Tray.Delete()
    Tray.Add("Show Manager", ShowUI)
    Tray.Add()
    Tray.Add("Exit", (*) => ExitApp())
    Tray.Default := "Show Manager"
}