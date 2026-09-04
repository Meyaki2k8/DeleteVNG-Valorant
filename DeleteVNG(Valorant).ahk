#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; --- Khởi tạo & Kiểm tra Quyền ---
CheckAdmin()
InitEnvironment()

; --- Giao diện & Core Loop ---
BuildUI()
BuildTray()
RegisterHoverControls()
RefreshUI()
MyGui.Show("w500 h500")
ApplyRoundedCorners()
ApplyTextPadding()
DeselectPathText()
LogMsg("Ứng dụng khởi động (v" App.Version ").", "START")

SetTimer(GameWatcherLoop, 1000)
SetTimer(CheckForUpdates, -3000)

OnMessage(0x0201, WM_LBUTTONDOWN)
OnMessage(0x0200, WM_MOUSEMOVE)


; ==============================================================================
; CORE ARCHITECTURE: CẤU HÌNH & TRẠNG THÁI
; ============================================================================== 
InitEnvironment() {
    global App, Config, State, C, HoverMap, lastHwnd, LogEdit

    App := {
        Version: "1.1",
        Name: "DeleteVNGValorant",
        RegKey: "HKCU\Software\DeleteVNGValorant",
        UpdateUrl: "https://raw.githubusercontent.com/Meyaki2k8/DeleteVNG-Valorant/main/version.json",
        ReleaseUrl: "https://github.com/Meyaki2k8/DeleteVNG-Valorant/releases",
        TargetProcess: "VALORANT-Win64-Shipping.exe",
        Files: [
            "VNGLogo-WindowsClient.pak",
            "VNGLogo-WindowsClient.sig",
            "VNGLogo-WindowsClient.ucas",
            "VNGLogo-WindowsClient.utoc"
        ]
    }

    defaultTheme := IsSystemDarkMode() ? 1 : 2

    MigrateLegacyStartup()

    Config := {
        PaksPath: RegReadSafe(App.RegKey, "PaksPath", "C:\Riot Games\VALORANT\live\ShooterGame\Content\Paks"),
        DelaySec: Max(0, Integer(RegReadSafe(App.RegKey, "DelaySec", 0))),
        MinimizeTray: Integer(RegReadSafe(App.RegKey, "MinimizeToTray", 1)),
        ThemeMode: Integer(RegReadSafe(App.RegKey, "ThemeMode", defaultTheme)),
        StartupEnabled: StartupTaskExists()
    }

    State := {
        IsGameRunning: false,
        ActionScheduled: false,
        IsUpdating: false
    }

    C := MatrixColors(Config.ThemeMode == 1)
    HoverMap := Map()
    lastHwnd := 0
    LogEdit := 0
}


; ==============================================================================
; ENGINE TỰ ĐỘNG HÓA & LOGGING
; ============================================================================== 
GameWatcherLoop(*) {
    global App, State, Config, StatusDot, C

    isRunning := ProcessExist(App.TargetProcess) != 0

    ; Game vừa bật
    if (isRunning && !State.IsGameRunning) {
        State.IsGameRunning := true
        State.ActionScheduled := true
        StatusDot.Opt("c" C.WARNING)
        LogMsg("Game khởi động.", "EVENT")

        if (Config.DelaySec > 0) {
            LogMsg("Hẹn xử lý sau " Config.DelaySec " giây.", "EVENT")
            SetTimer(ExecuteAction, -Config.DelaySec * 1000)
        } else {
            ExecuteAction()
        }
    }

    ; Game vừa tắt
    else if (!isRunning && State.IsGameRunning) {
        State.IsGameRunning := false
        State.ActionScheduled := false
        StatusDot.Opt("c" C.SUCCESS)
        LogMsg("Game đã tắt.", "EVENT")
        RefreshUI()
    }
}


ExecuteAction() {
    global App, State, Config

    ; Check lại process trước khi thực hiện hành động
    if (!State.ActionScheduled || !ProcessExist(App.TargetProcess)) {
        LogMsg("Hủy hành động: Game đã tắt trước khi hết thời gian chờ.", "WARN")
        return
    }

    State.ActionScheduled := false
    LogMsg("Bắt đầu dọn dẹp file VNG.", "ACTION")

    for Name in App.Files {
        fullPath := Config.PaksPath "\" Name
        if FileExist(fullPath)
            SafeDeleteAsync(fullPath, 5)
    }
}


SafeDeleteAsync(FilePath, RetriesLeft) {
    try {
        FileDelete(FilePath)
        LogMsg("Đã xóa file: " FilePath, "SUCCESS")
        RefreshUI()
    } catch {
        if (RetriesLeft > 1) {
            LogMsg("File đang bị khóa. Thử lại sau 1 giây (còn " (RetriesLeft - 1) " lần): " FilePath, "RETRY")
            SetTimer(() => SafeDeleteAsync(FilePath, RetriesLeft - 1), -1000)
        } else {
            LogMsg("Không thể xóa file: " FilePath, "ERROR")
            ShowToast("Lỗi xóa file: " FilePath, "Cảnh báo")
        }
    }
}


; ==============================================================================
; LOG TÍCH HỢP TRỰC TIẾP VÀO UI - KHÔNG TẠO FILE .LOG
; ============================================================================== 
LogMsg(msg, Level := "INFO") {
    global LogEdit

    try {
        if !IsObject(LogEdit)
            return

        timestamp := FormatTime(, "HH:mm:ss")
        line := "[" timestamp "] " Format("{:-7}", Level) " | " msg
        current := LogEdit.Value
        LogEdit.Value := current ? current "`r`n" line : line

        ; Giới hạn tối đa 150 dòng
        lines := StrSplit(LogEdit.Value, "`n")
        if (lines.Length > 150) {
            lines.RemoveAt(1)
            newText := ""
            for i, item in lines
                newText .= (i > 1 ? "`r`n" : "") Trim(item, "`r`n")
            LogEdit.Value := newText
        }

        ; Cuộn xuống cuối
        SendMessage(0x00B1, -1, -1, LogEdit.Hwnd) ; EM_SETSEL
        SendMessage(0x00B7, 0, 0, LogEdit.Hwnd)   ; EM_SCROLLCARET
    }
}


; ==============================================================================
; NON-BLOCKING UPDATER
; ============================================================================== 
CheckForUpdates(*) {
    global App, State

    if State.IsUpdating
        return

    State.IsUpdating := true

    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.Open("GET", App.UpdateUrl "?t=" A_TickCount, true)
        req.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) ValorantTool/" App.Version)
        req.SetRequestHeader("Cache-Control", "no-cache")
        req.Send()
        SetTimer(() => PollUpdateReq(req), 100)
    } catch {
        State.IsUpdating := false
    }
}


PollUpdateReq(req) {
    global App, State

    try {
        if (req.ReadyState != 4)
            return

        SetTimer(, 0)

        if (req.Status == 200) {
            if RegExMatch(req.ResponseText, '"version"\s*:\s*"([^"]+)"', &match) {
                if (VerCompare(match[1], App.Version) > 0) {
                    LogMsg("Phát hiện phiên bản mới: v" match[1], "UPDATE")
                    if MsgBox("Phiên bản mới (v" match[1] ") đã có sẵn!`nBạn có muốn tải về không?", "Cập nhật ứng dụng", "YesNo Iconi") = "Yes"
                        Run(App.ReleaseUrl)
                }
            }
        }
    } catch {
        SetTimer(, 0)
        LogMsg("Không thể kiểm tra cập nhật.", "WARN")
    } finally {
        State.IsUpdating := false
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


; ==============================================================================
; UI XÂY DỰNG & QUẢN LÝ
; ============================================================================== 
BuildUI() {
    global MyGui, PathEdit, DelayEdit, MinimizeBtn, StartupBtn, BrowseBtn
    global FileCountText, FileStateText, PathStateText, DummyFocus, StatusDot
    global BtnMin, BtnClose, BtnTheme, Panel1, Panel2, Panel3, HeaderTitle, VersionTag, LogEdit
    global C, App, Config

    MyGui := Gui("-Caption -Border +MinimizeBox", "Valorant Tool")
    MyGui.BackColor := C.BG
    MyGui.MarginX := MyGui.MarginY := 0
    MyGui.OnEvent("Close", (*) => OnClose())

    DummyFocus := MyGui.Add("Button", "x-100 y-100 w1 h1", "")
    StatusDot := MyGui.Add("Text", "x16 y10 w16 h20 BackgroundTrans c" C.SUCCESS, "●")
    StatusDot.SetFont("s12", "Segoe UI")

    MyGui.SetFont("s10 bold c" C.TEXT, "Segoe UI")
    HeaderTitle := MyGui.Add("Text", "x34 y10 w150 h24 BackgroundTrans", "Valorant Tool")
    MyGui.SetFont("s8 bold c" C.ACCENT, "Segoe UI")
    VersionTag := MyGui.Add("Text", "x184 y12 w60 h20 BackgroundTrans", "v" App.Version)

    BtnTheme := MyGui.Add("Text", "x330 y6 w80 h28 Background" C.BG " c" C.MUTED " Center +0x200", Config.ThemeMode == 1 ? "🌙 Dark" : "☀️ Light")
    BtnMin := MyGui.Add("Text", "x420 y6 w32 h28 Background" C.BG " c" C.MUTED " Center +0x200", "—")
    BtnClose := MyGui.Add("Text", "x456 y6 w38 h28 Background" C.BG " c" C.MUTED " Center +0x200", "✕")

    BtnTheme.SetFont("s8 bold", "Segoe UI")
    BtnMin.SetFont("s10 bold", "Segoe UI")
    BtnClose.SetFont("s10 bold", "Segoe UI")
    BtnTheme.OnEvent("Click", CycleTheme)
    BtnMin.OnEvent("Click", MinimizeApp)
    BtnClose.OnEvent("Click", (*) => OnClose())

    ; Mục 1: Cấu hình thư mục
    UILabel("GAME DIRECTORY", 20, 42)
    Panel1 := MyGui.Add("Text", "x20 y60 w460 h78 Background" C.PANEL)

    MyGui.SetFont("s9 c" C.TEXT, "Segoe UI")
    PathEdit := MyGui.Add("Text", "x32 y72 w326 h26 Background" C.INPUT " c" C.TEXT " +0x200", Config.PaksPath)
    BrowseBtn := ButtonText("Browse", 368, 72, 100, 26, C.ACCENT, "FFFFFF")
    BrowseBtn.OnEvent("Click", SelectFolder)

    MyGui.SetFont("s8 c" C.MUTED, "Segoe UI")
    PathStateText := MyGui.Add("Text", "x32 y106 w430 h18 BackgroundTrans", "")

    ; Mục 2: Automation
    UILabel("AUTOMATION", 20, 150)
    Panel2 := MyGui.Add("Text", "x20 y168 w460 h86 Background" C.PANEL)

    MyGui.SetFont("s9 c" C.MUTED, "Segoe UI")
    MyGui.Add("Text", "x32 y182 w90 h26 BackgroundTrans +0x200 vDelayLbl1", "Launch delay:")
    DelayEdit := MyGui.Add("Edit", "x125 y182 w50 h26 Background" C.INPUT " c" C.TEXT " Number -E0x200 -Border Center -VScroll", Config.DelaySec)
    DelayEdit.OnEvent("LoseFocus", (*) => SaveSettings())

    MyGui.SetFont("s8 c" C.MUTED, "Segoe UI")
    MyGui.Add("Text", "x182 y182 w50 h26 BackgroundTrans +0x200 vDelayLbl2", "seconds")
    MyGui.SetFont("s8 bold c" C.ACCENT, "Segoe UI")
    MyGui.Add("Text", "x250 y182 w210 h26 BackgroundTrans Right +0x200 vDelayRec", "Recommended: 0s")

    MinimizeBtn := MyGui.Add("Text", "x32 y216 w208 h28 Center +0x200", "")
    StartupBtn := MyGui.Add("Text", "x252 y216 w216 h28 Center +0x200", "")

    RenderToggle(MinimizeBtn, Config.MinimizeTray, "Minimize to tray")
    RenderToggle(StartupBtn, Config.StartupEnabled, "Start with Windows")
    MinimizeBtn.OnEvent("Click", ToggleMinimize)
    StartupBtn.OnEvent("Click", ToggleStartup)

    ; Mục 3: File Monitoring
    UILabel("VNG LOGO FILES", 20, 266)
    Panel3 := MyGui.Add("Text", "x20 y284 w460 h60 Background" C.PANEL)

    MyGui.SetFont("s14 bold c" C.TEXT, "Segoe UI")
    FileCountText := MyGui.Add("Text", "x32 y300 w70 h28 BackgroundTrans +0x200", "0 / " App.Files.Length)
    MyGui.SetFont("s8 c" C.MUTED, "Segoe UI")
    FileStateText := MyGui.Add("Text", "x105 y300 w340 h28 BackgroundTrans +0x200", "Checking...")

    ; Mục 4: Activity Log
    UILabel("ACTIVITY LOG", 20, 350)
    LogEdit := MyGui.Add("Edit", "x20 y368 w460 h112 ReadOnly -Wrap Background" C.INPUT " c" C.TEXT)
    LogEdit.SetFont("s8", "Consolas")
}


; ==============================================================================
; WINDOW / HOVER
; ============================================================================== 
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global MyGui, DummyFocus
    if (hwnd = MyGui.Hwnd)
        PostMessage(0xA1, 2,,, "ahk_id " MyGui.Hwnd)
    else
        DummyFocus.Focus()
}


WM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global lastHwnd, HoverMap, C, Config
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
            case "close":        item.ctrl.Opt("Background" C.DANGER)
            case "toggle_min":   item.ctrl.Opt("Background" (Config.MinimizeTray ? C.ACTIVE_BG : C.HOVER))
            case "toggle_start": item.ctrl.Opt("Background" (Config.StartupEnabled ? C.ACTIVE_BG : C.HOVER))
            case "browse":       item.ctrl.Opt("Background" C.ACCENT_HOVER)
            default:             item.ctrl.Opt("Background" C.HOVER)
        }

        lastHwnd := hwnd
        SetTimer(CheckHoverLeave, 50)
    }
}


CheckHoverLeave() {
    global lastHwnd
    if !lastHwnd
        return SetTimer(CheckHoverLeave, 0)

    MouseGetPos(,,, &currHwnd, 1)
    if (currHwnd != lastHwnd) {
        ResetControlBg(lastHwnd)
        lastHwnd := 0
        SetTimer(CheckHoverLeave, 0)
    }
}


ResetControlBg(hwnd) {
    global HoverMap, C, Config
    if !HoverMap.Has(hwnd)
        return

    item := HoverMap[hwnd]
    switch item.type {
        case "normal", "close": item.ctrl.Opt("Background" C.BG)
        case "browse":          item.ctrl.Opt("Background" C.ACCENT)
        case "toggle_min":      RenderToggle(item.ctrl, Config.MinimizeTray, "Minimize to tray")
        case "toggle_start":    RenderToggle(item.ctrl, Config.StartupEnabled, "Start with Windows")
    }
}


RegisterHoverControls() {
    global HoverMap, BtnMin, BtnClose, BtnTheme, BrowseBtn, MinimizeBtn, StartupBtn
    HoverMap := Map(
        BtnMin.Hwnd, {ctrl: BtnMin, type: "normal"},
        BtnClose.Hwnd, {ctrl: BtnClose, type: "close"},
        BtnTheme.Hwnd, {ctrl: BtnTheme, type: "normal"},
        BrowseBtn.Hwnd, {ctrl: BrowseBtn, type: "browse"},
        MinimizeBtn.Hwnd, {ctrl: MinimizeBtn, type: "toggle_min"},
        StartupBtn.Hwnd, {ctrl: StartupBtn, type: "toggle_start"}
    )
}


; ==============================================================================
; THEME
; ============================================================================== 
CycleTheme(*) {
    global Config, App, C, MyGui, Panel1, Panel2, Panel3, BtnTheme, BtnMin, BtnClose
    global HeaderTitle, VersionTag, PathEdit, DelayEdit, BrowseBtn, MinimizeBtn, StartupBtn, LogEdit

    clipBackup := ClipboardAll()
    Config.ThemeMode := Config.ThemeMode == 1 ? 2 : 1

    try RegWrite(Config.ThemeMode, "REG_DWORD", App.RegKey, "ThemeMode")
    C := MatrixColors(Config.ThemeMode == 1)

    DllCall("SendMessage", "Ptr", MyGui.Hwnd, "UInt", 0x000B, "Ptr", 0, "Ptr", 0)
    MyGui.BackColor := C.BG
    Panel1.Opt("Background" C.PANEL), Panel2.Opt("Background" C.PANEL), Panel3.Opt("Background" C.PANEL)

    BtnTheme.Text := Config.ThemeMode == 1 ? "🌙 Dark" : "☀️ Light"
    BtnTheme.Opt("Background" C.BG " c" C.MUTED)
    BtnMin.Opt("Background" C.BG " c" C.MUTED)
    BtnClose.Opt("Background" C.BG " c" C.MUTED)
    HeaderTitle.Opt("c" C.TEXT)
    VersionTag.Opt("c" C.ACCENT)

    MyGui["DelayLbl1"].Opt("c" C.MUTED)
    MyGui["DelayLbl2"].Opt("c" C.MUTED)
    MyGui["DelayRec"].Opt("c" C.ACCENT)
    PathEdit.Opt("Background" C.INPUT " c" C.TEXT)
    DelayEdit.Opt("Background" C.INPUT " c" C.TEXT)
    LogEdit.Opt("Background" C.INPUT " c" C.TEXT)
    BrowseBtn.Opt("Background" C.ACCENT " cFFFFFF")

    Loop 4
        MyGui["UILabel" A_Index].Opt("c" C.MUTED)

    RenderToggle(MinimizeBtn, Config.MinimizeTray, "Minimize to tray")
    RenderToggle(StartupBtn, Config.StartupEnabled, "Start with Windows")
    RefreshUI()

    DllCall("SendMessage", "Ptr", MyGui.Hwnd, "UInt", 0x000B, "Ptr", 1, "Ptr", 0)
    WinRedraw(MyGui.Hwnd)
    SetTimer(() => (A_Clipboard := clipBackup), -50)
}


RefreshUI(*) {
    global Config, App, PathEdit, PathStateText, FileCountText, FileStateText, C
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

    for Name in App.Files
        if FileExist(Path "\" Name)
            Count++

    FileCountText.Text := Count " / " App.Files.Length
    FileCountText.Opt("c" C.TEXT)
    FileStateText.Text := Count = App.Files.Length ? "Target files present" : Count ? "Partial files present" : "No VNG files (Clean)"
    FileStateText.Opt(Count ? "c" C.WARNING : "c" C.SUCCESS)
}


SaveSettings(*) {
    global App, Config, PathEdit, DelayEdit
    try {
        RegWrite(Trim(PathEdit.Text), "REG_SZ", App.RegKey, "PaksPath")
        newDelay := Max(0, Integer(Trim(DelayEdit.Value) || 0))
        RegWrite(newDelay, "REG_DWORD", App.RegKey, "DelaySec")
        Config.DelaySec := newDelay
        RegWrite(Config.MinimizeTray, "REG_DWORD", App.RegKey, "MinimizeToTray")
        LogMsg("Đã lưu cài đặt. Delay = " newDelay " giây.", "CONFIG")
    } catch as Err {
        LogMsg("Lỗi lưu Registry: " Err.Message, "ERROR")
        ShowToast("Không thể lưu cấu hình", "Lỗi")
    }
}


SelectFolder(*) {
    global PathEdit, Config, MyGui
    MyGui.Opt("+OwnDialogs")
    if (Selected := FileSelect("D", Config.PaksPath, "Select Folder")) != "" {
        Config.PaksPath := RegExReplace(Selected, "\\$")
        PathEdit.Text := Config.PaksPath
        SaveSettings()
        RefreshUI()
        ApplyTextPadding()
        DeselectPathText()
    }
}


ToggleMinimize(*) {
    global Config, MinimizeBtn
    Config.MinimizeTray := !Config.MinimizeTray
    RenderToggle(MinimizeBtn, Config.MinimizeTray, "Minimize to tray")
    SaveSettings()
}


ToggleStartup(*) {
    global Config, StartupBtn
    try {
        wantEnabled := !Config.StartupEnabled
        success := wantEnabled ? EnableAutoStartTask() : DisableAutoStartTask()

        if !success {
            LogMsg("Không thể " (wantEnabled ? "bật" : "tắt") " Start with Windows (schtasks thất bại).", "ERROR")
            ShowToast("Không thể cập nhật Task Scheduler", "Lỗi")
            return
        }

        Config.StartupEnabled := wantEnabled
        RenderToggle(StartupBtn, Config.StartupEnabled, "Start with Windows")
    } catch as Err {
        LogMsg("Lỗi Startup: " Err.Message, "ERROR")
    }
}


; Dùng Task Scheduler (RL HIGHEST + ONLOGON) thay vì HKCU\...\Run.
; Lý do: app này luôn chạy elevated (CheckAdmin), nhưng Run-key launch
; qua Explorer KHÔNG THỂ tự elevate -> mỗi lần đăng nhập sẽ hiện UAC
; prompt, và nếu user không bấm Yes kịp thì app coi như không tự chạy.
; Task Scheduler với "Run with highest privileges" bỏ qua UAC consent
; UI vì service tự cấp token elevated cho task.
StartupTaskExists() {
    global App
    exitCode := RunWait('schtasks.exe /Query /TN "' App.Name '"', , "Hide")
    return exitCode = 0
}


EnableAutoStartTask() {
    global App
    exePath := A_IsCompiled ? A_ScriptFullPath : A_AhkPath
    trValue := '\"' exePath '\"'
    if !A_IsCompiled
        trValue .= ' \"' A_ScriptFullPath '\"'

    cmd := 'schtasks.exe /Create /F /RL HIGHEST /SC ONLOGON /TN "' App.Name '" /TR "' trValue '"'
    exitCode := RunWait(cmd, , "Hide")
    return exitCode = 0
}


DisableAutoStartTask() {
    global App
    exitCode := RunWait('schtasks.exe /Delete /F /TN "' App.Name '"', , "Hide")
    return exitCode = 0
}


; Dọn dẹp Run-key entry từ bản cũ (nếu có) và chuyển sang Task Scheduler
; để user nâng cấp không bị mất cấu hình "Start with Windows".
MigrateLegacyStartup() {
    global App
    legacyKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
    old := RegReadSafe(legacyKey, App.Name, "")
    if (old != "") {
        try RegDelete(legacyKey, App.Name)
        EnableAutoStartTask()
    }
}


CheckAdmin() {
    if !A_IsAdmin {
        try {
            Run(A_IsCompiled ? '*RunAs "' A_ScriptFullPath '"' : '*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"')
            ExitApp
        } catch {
            MsgBox("Chương trình cần quyền Administrator để thao tác với file của Riot Games.", "Yêu cầu quyền Admin", "IconX")
            ExitApp
        }
    }
}


; ==============================================================================
; TRAY
; ============================================================================== 
BuildTray() {
    A_IconTip := "Valorant Tool"
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Show Manager", ShowUI)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit", (*) => ExitApp())
    A_TrayMenu.Default := "Show Manager"
}


ShowUI(*) {
    global lastHwnd, BtnMin, BtnClose, BtnTheme, BrowseBtn, MinimizeBtn, StartupBtn, MyGui
    lastHwnd := 0
    ResetControlBg(BtnMin.Hwnd), ResetControlBg(BtnClose.Hwnd), ResetControlBg(BtnTheme.Hwnd)
    ResetControlBg(BrowseBtn.Hwnd), ResetControlBg(MinimizeBtn.Hwnd), ResetControlBg(StartupBtn.Hwnd)
    RefreshUI()
    MyGui.Show()
    ApplyTextPadding()
    DeselectPathText()
}


MinimizeApp(*) {
    global BtnMin, MyGui
    ResetControlBg(BtnMin.Hwnd)
    MyGui.Minimize()
}


OnClose(*) {
    global Config, MyGui
    if Config.MinimizeTray
        MyGui.Hide()
    else
        ExitApp()
}


; ==============================================================================
; UI HELPERS
; ============================================================================== 
RenderToggle(Ctrl, IsChecked, LabelText) {
    global C
    Ctrl.Opt("Background" (IsChecked ? C.ACTIVE_BG : C.INPUT))
    Ctrl.SetFont(IsChecked ? "s8 bold c" C.ACCENT : "s8 c" C.MUTED, "Segoe UI")
    Ctrl.Text := (IsChecked ? "✓  " : "✕  ") LabelText
}


ButtonText(Text, X, Y, W, H, Bg, FontColor) {
    global MyGui
    MyGui.SetFont("s8 bold c" (InStr(FontColor, "0x") ? FontColor : "0x" FontColor), "Segoe UI")
    return MyGui.Add("Text", "x" X " y" Y " w" W " h" H " Background" Bg " Center +0x200", Text)
}


UILabel(Text, X, Y) {
    global MyGui, C
    static count := 1
    MyGui.SetFont("s8 bold c" C.MUTED, "Segoe UI")
    return MyGui.Add("Text", "x" X " y" Y " w460 h16 BackgroundTrans vUILabel" count++, Text)
}


ShowToast(Msg, Title := "Valorant Tool") => TrayTip(Msg, Title, "Iconi Mute")


; ==============================================================================
; SYSTEM HELPERS
; ============================================================================== 
IsSystemDarkMode() {
    try return RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") == 0
    return true
}


MatrixColors(isDark) => isDark
    ? {
        BG: "0x0B0E14",
        PANEL: "0x131722",
        INPUT: "0x1A202C",
        HOVER: "0x2D3748",
        ACTIVE_BG: "0x3D1F2D",
        ACCENT: "0xFF4655",
        ACCENT_HOVER: "0xE03E4D",
        TEXT: "0xFFFFFF",
        MUTED: "0x718096",
        SUCCESS: "0x10B981",
        WARNING: "0xF59E0B",
        DANGER: "0xE11D48"
    }
    : {
        BG: "0xF8FAFC",
        PANEL: "0xFFFFFF",
        INPUT: "0xEDF2F7",
        HOVER: "0xE2E8F0",
        ACTIVE_BG: "0xFCE7F3",
        ACCENT: "0xFF4655",
        ACCENT_HOVER: "0xE03E4D",
        TEXT: "0x1A202C",
        MUTED: "0x718096",
        SUCCESS: "0x059669",
        WARNING: "0xD97706",
        DANGER: "0xE11D48"
    }


ApplyTextPadding() => SetEditPadding(DelayEdit, 4)


SetEditPadding(Ctrl, TopPad := 4) => (
    rc := Buffer(16, 0),
    DllCall("user32\GetClientRect", "Ptr", Ctrl.Hwnd, "Ptr", rc),
    NumPut("int", TopPad, rc, 4),
    SendMessage(0x00B3, 0, rc.Ptr, Ctrl.Hwnd)
)


DeselectPathText() {
    global DummyFocus
    try DummyFocus.Focus()
}


RegReadSafe(Key, ValueName, Default) {
    try return RegRead(Key, ValueName)
    return Default
}


ApplyRoundedCorners() => WinSetRegion("0-0 w500 h500 r12-12", "ahk_id " MyGui.Hwnd)
