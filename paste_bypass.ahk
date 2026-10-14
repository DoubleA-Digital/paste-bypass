#Requires AutoHotkey v2.0
#SingleInstance Force

; ════════════════════════════════════════════════════════════
;  PASTE BYPASS — Auto Typer  v3.0
;  Modes: Computer Science  |  English
;
;  Ctrl+Shift+V  = Start      Ctrl+Shift+P = Pause/Resume
;  Escape        = Emergency Stop (only while running)
; ════════════════════════════════════════════════════════════

; ─── Keyboard adjacency map for realistic typo simulation ────
global NEARBY := Map(
    "a","sqwz",   "b","vghn",   "c","xvdf",   "d","srfce",
    "e","wrsdf",  "f","drtgvc", "g","ftyhbv",  "h","gyujbn",
    "i","uojk",   "j","huikmn", "k","jliopm",  "l","kop",
    "m","njk",    "n","bhjm",   "o","iklp",    "p","lo",
    "q","wa",     "r","edtf",   "s","aqwedxz", "t","rfyg",
    "u","yihj",   "v","cfgb",   "w","qase",    "x","zscd",
    "y","tugh",   "z","asx"
)

; ─── Runtime state ───────────────────────────────────────────
global g_state      := "idle"   ; idle|countdown|typing|paused|stopped|done
global g_mode       := "CS"     ; "CS" = Computer Science  |  "EN" = English
global g_stop       := false
global g_pause      := false
global g_charsOut   := 0
global g_wordsOut   := 0
global g_startTime  := 0
global g_totalCh    := 0
global g_text       := ""       ; text queued for typing
global g_origText   := ""       ; English-mode backup for Revert
global g_targetWin  := 0        ; locked target HWND
global WS_EX_NOACTIVATE := 0x08000000
global CODE_KEY_DELAY   := 25   ; ms between editor-control keystrokes in CS mode

; ─── Config file (persists API key) ──────────────────────────
global CFG_FILE := A_ScriptDir . "\paste_bypass_config.ini"
EnsureConfigExists()
global g_apiKey := IniRead(CFG_FILE, "API", "ClaudeKey", "")

; ─── Shortcut on first run ───────────────────────────────────
CreateShortcutIfNeeded()

; ════════════════════════════════════════════════════════════
;  BUILD GUI  (dark theme  #1e1e2e  —  clean tabbed layout)
; ════════════════════════════════════════════════════════════
global MyGui := Gui("+AlwaysOnTop", "Paste Bypass — Auto Typer")
MyGui.BackColor := "1e1e2e"
MyGui.SetFont("s11 q5 cF8F8F2", "Segoe UI")
MyGui.OnEvent("Close", (*) => ExitApp())

; ── Title ────────────────────────────────────────────────────
MyGui.SetFont("s16 Bold cF8F8F2")
MyGui.Add("Text", "x0 y14 w480 Center", "Paste Bypass")
MyGui.SetFont("s10 c7070A0")
MyGui.Add("Text", "x0 y42 w480 Center", "Auto-types text with human-like behaviour")
MyGui.Add("Text", "x20 y66 w440 h1 +0x10")

; ── Text Preview ─────────────────────────────────────────────
MyGui.SetFont("s9 Bold c888899")
MyGui.Add("Text", "x20 y78", "TEXT  /  CLIPBOARD PREVIEW")
MyGui.SetFont("s11 cF8F8F2")
global Preview := MyGui.Add("Edit",
    "x20 y96 w440 h100 +Multi +VScroll +Background2a2a3e")
MyGui.SetFont("s10 cF8F8F2")
global BtnRefresh := MyGui.Add("Button", "x20  y204 w96  h26", "Refresh")
global BtnClear   := MyGui.Add("Button", "x122 y204 w76  h26", "Clear")
global BtnUseText := MyGui.Add("Button", "x204 y204 w122 h26", "Use This Text")
global BtnCopyPrv := MyGui.Add("Button", "x332 y204 w128 h26", "Copy Preview")
BtnRefresh.OnEvent("Click", RefreshPreview)
BtnClear.OnEvent("Click",   ClearPreview)
BtnUseText.OnEvent("Click", LoadPreviewText)
BtnCopyPrv.OnEvent("Click", CopyPreview)
MyGui.Add("Text", "x20 y238 w440 h1 +0x10")

; ── Tools — tabbed CS / EN ───────────────────────────────────
MyGui.SetFont("s9 Bold c888899")
MyGui.Add("Text", "x20 y250", "TOOLS")
global ToolsTab := MyGui.Add("Tab3", "x20 y268 w440 h172", ["CS Mode", "EN Mode"])
ToolsTab.OnEvent("Change", SwitchMode)

; ─── Tab 1: CS Mode ──────────────────────────────────────────
ToolsTab.UseTab(1)
MyGui.SetFont("s11 Bold cF8F8F2")
MyGui.Add("Text", "x36 y300 w400", "Clean Code Typing — always on")
MyGui.SetFont("s9 c888899")
MyGui.Add("Text", "x36 y324 w400",
    "• Overrides the editor's auto-indent with your exact indentation`n"
    . "• Removes auto-closed ) ] } `" ' so nothing gets doubled`n"
    . "• Keeps every line intact — autocomplete can't hijack Enter`n"
    . "• Tabs → 4 spaces, trailing whitespace trimmed")
MyGui.SetFont("s10 cF8F8F2")
global BtnFmt := MyGui.Add("Button", "x36 y400 w120 h26", "Format Code")
BtnFmt.OnEvent("Click", FormatCode)
MyGui.SetFont("s9 c666688")
MyGui.Add("Text", "x164 y406", "Normalises indentation to 4 spaces")

; ─── Tab 2: EN Mode ──────────────────────────────────────────
ToolsTab.UseTab(2)
MyGui.SetFont("s10 c888899")
MyGui.Add("Text", "x36 y302 w100", "Writing style:")
MyGui.SetFont("s11 cF8F8F2")
global RadioSimple := MyGui.Add("Radio",
    "x142 y301 w88 cF8F8F2 Background2a2a3e +Checked", " Simple")
global RadioStrong := MyGui.Add("Radio",
    "x234 y301 w162 cF8F8F2 Background2a2a3e", " Strong / Academic")
MyGui.SetFont("s9 c666688")
MyGui.Add("Text", "x36 y322", "Simple = natural student tone     Strong = polished academic")
MyGui.SetFont("s11 cF8F8F2")
global BtnHumanize := MyGui.Add("Button", "x36  y344 w132 h28", "Humanize Text")
global BtnPolish   := MyGui.Add("Button", "x174 y344 w132 h28", "Polish Grammar")
global BtnRevert   := MyGui.Add("Button", "x312 y344 w104 h28", "Revert")
BtnHumanize.OnEvent("Click", HumanizeText)
BtnPolish.OnEvent("Click",   PolishGrammar)
BtnRevert.OnEvent("Click",   RevertText)
MyGui.SetFont("s10 c888899")
MyGui.Add("Text", "x36 y382 w110", "Claude API Key:")
MyGui.SetFont("s11 cF8F8F2")
global TxtApiKey := MyGui.Add("Edit",
    "x150 y379 w300 h24 +Password +Background2a2a3e", g_apiKey)
TxtApiKey.OnEvent("Change", SaveApiKey)
MyGui.SetFont("s9 c666688")
MyGui.Add("Text", "x36 y412", "Saved automatically to paste_bypass_config.ini")

ToolsTab.UseTab(0)
MyGui.Add("Text", "x20 y448 w440 h1 +0x10")

; ── Typing Speed ──────────────────────────────────────────────
MyGui.SetFont("s9 Bold c888899")
MyGui.Add("Text", "x20 y460", "SPEED")
MyGui.SetFont("s10 c888899")
MyGui.Add("Text", "x20 y478 w50", "WPM:")
global WpmSlider := MyGui.Add("Slider",
    "x74 y474 w316 h30 Range10-300 TickInterval50 Line5 Page20", 80)
WpmSlider.OnEvent("Change", UpdateWpmLabel)
global WpmLabel := MyGui.Add("Text", "x394 y480 w66 Right cF8F8F2", "80 WPM")
MyGui.Add("Text", "x20 y508 w440 h1 +0x10")

; ── Behaviour ─────────────────────────────────────────────────
MyGui.SetFont("s9 Bold c888899")
MyGui.Add("Text", "x20 y520", "BEHAVIOUR")
MyGui.SetFont("s11 cF8F8F2")
global ChkHuman := MyGui.Add("CheckBox",
    "x20 y536 w202 +Checked cF8F8F2 Background1e1e2e", " Humanized Typing")
global ChkMist  := MyGui.Add("CheckBox",
    "x230 y536 w144 cF8F8F2 Background1e1e2e", " Make Mistakes")
MyGui.SetFont("s10 c888899")
MyGui.Add("Text", "x230 y558 w50", "Freq:")
MyGui.SetFont("s10 cF8F8F2")
global MistFreqLow  := MyGui.Add("Radio",
    "x282 y557 w60 cF8F8F2 Background1e1e2e +Checked", " Low")
global MistFreqMed  := MyGui.Add("Radio",
    "x344 y557 w60 cF8F8F2 Background1e1e2e", " Med")
global MistFreqHigh := MyGui.Add("Radio",
    "x406 y557 w54 cF8F8F2 Background1e1e2e", " High")
MyGui.Add("Text", "x20 y578 w440 h1 +0x10")

; ── Controls ─────────────────────────────────────────────────
MyGui.SetFont("s9 Bold c888899")
MyGui.Add("Text", "x20 y590", "CONTROLS")
MyGui.SetFont("s12 Bold cF8F8F2")
global BtnStart  := MyGui.Add("Button", "x20  y606 w160 h38", "Start")
global BtnPause  := MyGui.Add("Button", "x186 y606 w84  h38", "Pause")
global BtnResume := MyGui.Add("Button", "x276 y606 w84  h38", "Resume")
global BtnStop   := MyGui.Add("Button", "x366 y606 w94  h38", "Stop")
BtnPause.Enabled  := false
BtnResume.Enabled := false
BtnStop.Enabled   := false
BtnStart.OnEvent("Click",  StartTyping)
BtnPause.OnEvent("Click",  PauseTyping)
BtnResume.OnEvent("Click", ResumeTyping)
BtnStop.OnEvent("Click",   StopTyping)
MyGui.Add("Text", "x20 y652 w440 h1 +0x10")

; ── Status ───────────────────────────────────────────────────
MyGui.SetFont("s9 Bold c888899")
MyGui.Add("Text", "x20 y664", "STATUS")
MyGui.SetFont("s10 c888899")
MyGui.Add("Text", "x20 y682 w92", "State:")
MyGui.Add("Text", "x248 y682 w92", "WPM:")
MyGui.Add("Text", "x20 y702 w92", "Characters:")
MyGui.Add("Text", "x248 y702 w92", "Words:")
MyGui.Add("Text", "x20 y722 w92", "Time left:")
MyGui.SetFont("s10 Bold cF8F8F2")
global LblState  := MyGui.Add("Text", "x116 y682 w126", "Idle")
global LblCurWpm := MyGui.Add("Text", "x344 y682 w116", "80 WPM")
global LblChars  := MyGui.Add("Text", "x116 y702 w126", "0")
global LblWords  := MyGui.Add("Text", "x344 y702 w116", "0")
global LblETA    := MyGui.Add("Text", "x116 y722 w126", "—")
global ProgressBar := MyGui.Add("Progress",
    "x20 y746 w440 h14 cGreen Background2a2a3e", 0)
MyGui.SetFont("s8 c444455")
MyGui.Add("Text", "x20 y768 w440 Center",
    "Ctrl+Shift+V = Start   ·   Esc = Emergency Stop   ·   Ctrl+Shift+P = Pause")

MyGui.Show("w480 h792")
RefreshPreview()

; ─── Tray menu ───────────────────────────────────────────────
A_TrayMenu.Delete()
A_TrayMenu.Add("Paste Bypass",  (*) => MyGui.Show())
A_TrayMenu.Add()
A_TrayMenu.Add("Start Typing",  StartTyping)
A_TrayMenu.Add("Pause/Resume",  TogglePause)
A_TrayMenu.Add("Stop Typing",   StopTyping)
A_TrayMenu.Add()
A_TrayMenu.Add("Exit",          (*) => ExitApp())
A_TrayMenu.Default := "Paste Bypass"
A_IconTip := "Paste Bypass — Auto Typer"

; ─── Timers ──────────────────────────────────────────────────
SetTimer(UpdateProgress,    500)
SetTimer(TrackTargetWindow, 200)

; ════════════════════════════════════════════════════════════
;  HOTKEYS
; ════════════════════════════════════════════════════════════
^+v::StartTyping()
^+p::TogglePause()

; $ = keyboard hook, so keys the script itself sends can't trigger this
#HotIf (g_state = "typing" || g_state = "paused" || g_state = "countdown")
$Escape::StopTyping()
#HotIf

; ════════════════════════════════════════════════════════════
;  MODE MANAGEMENT
; ════════════════════════════════════════════════════════════

SwitchMode(*) {
    global g_mode
    g_mode := (ToolsTab.Value = 1) ? "CS" : "EN"
    if (g_mode = "CS") {
        ChkMist.Value  := 0
        ChkHuman.Value := 0
    } else {
        ChkHuman.Value := 1
    }
}

; ════════════════════════════════════════════════════════════
;  PREVIEW CONTROLS
; ════════════════════════════════════════════════════════════

RefreshPreview(*) {
    txt := A_Clipboard
    Preview.Value := txt
    if (StrLen(txt) = 0)
        ShowTip("Clipboard is empty")
}

ClearPreview(*) {
    Preview.Value := ""
}

; Queue whatever is in the preview box as the text to type
LoadPreviewText(*) {
    global g_text
    g_text := Preview.Value
    n := StrLen(g_text)
    ShowTip(n > 0 ? n . " chars queued — click Start to type" : "Preview is empty")
}

CopyPreview(*) {
    A_Clipboard := Preview.Value
    ShowTip("Preview copied to clipboard")
}

; ════════════════════════════════════════════════════════════
;  COMPUTER SCIENCE TOOLS
; ════════════════════════════════════════════════════════════

; ─── Format Code: normalize indentation to 4 spaces ─────────
FormatCode(*) {
    raw  := Preview.Value
    if (StrLen(raw) = 0)
        return

    lines  := StrSplit(raw, "`n")
    result := ""

    for i, line in lines {
        ; Strip trailing whitespace
        line := RTrim(line, " `t")
        ; Convert leading tabs to 4 spaces
        leading := ""
        rest    := line
        while (SubStr(rest, 1, 1) = "`t") {
            leading .= "    "
            rest     := SubStr(rest, 2)
        }
        result .= leading . rest . (i < lines.Length ? "`n" : "")
    }

    Preview.Value := result
    ShowTip("Code formatted")
}

; ════════════════════════════════════════════════════════════
;  ENGLISH TOOLS  (require Claude API)
; ════════════════════════════════════════════════════════════

SaveApiKey(*) {
    global g_apiKey
    g_apiKey := TxtApiKey.Value
    IniWrite(g_apiKey, CFG_FILE, "API", "ClaudeKey")
}

RevertText(*) {
    global g_origText
    if (StrLen(g_origText) > 0) {
        Preview.Value := g_origText
        ShowTip("Text reverted to original")
    }
}

; ─── Humanize: rewrite to sound natural & student-like ───────
HumanizeText(*) {
    global g_origText
    txt := Preview.Value
    if (StrLen(txt) = 0) {
        ShowTip("Preview is empty")
        return
    }
    g_origText := txt

    style := RadioStrong.Value
        ? "polished, academic, and well-structured"
        : "natural, clear, and student-like without sounding robotic"

    prompt := "Rewrite the following text to sound " . style . ". "
        . "Keep the exact same meaning, facts, and structure. "
        . "Do NOT add new information or change any facts. "
        . "Return ONLY the rewritten text with no explanation or commentary.`n`n" . txt

    ShowTip("Calling Claude API…")
    BtnHumanize.Enabled := false
    SetTimer(() => RunApiAndUpdate(prompt, "Humanize"), -1)
}

; ─── Polish Grammar: fix grammar, spelling, punctuation ──────
PolishGrammar(*) {
    global g_origText
    txt := Preview.Value
    if (StrLen(txt) = 0) {
        ShowTip("Preview is empty")
        return
    }
    g_origText := txt

    prompt := "Fix all grammar, spelling, punctuation, and sentence flow issues in the text below. "
        . "Do NOT change the meaning, tone, or content. "
        . "Return ONLY the corrected text with no explanation or commentary.`n`n" . txt

    ShowTip("Calling Claude API…")
    BtnPolish.Enabled := false
    SetTimer(() => RunApiAndUpdate(prompt, "Polish"), -1)
}

; ─── Shared API call + preview update (runs in timer thread) ─
RunApiAndUpdate(prompt, caller) {
    result := CallClaudeAPI(prompt)

    ; Update preview and re-enable buttons on completion
    if (StrLen(result) > 0) {
        Preview.Value := result
        ShowTip("Done — review the text, then click Start or Revert")
    } else {
        ShowTip("API call failed — check your Claude API key in Section 3")
    }

    BtnHumanize.Enabled := true
    BtnPolish.Enabled   := true
}

; ─── HTTP call to Claude API (synchronous) ───────────────────
CallClaudeAPI(prompt) {
    if (StrLen(g_apiKey) = 0) {
        ShowTip("Enter your Claude API key in Section 3")
        return ""
    }

    model := "claude-haiku-4-5-20251001"
    body  := '{"model":"' . model . '","max_tokens":2048,'
          . '"messages":[{"role":"user","content":"' . EscapeJSON(prompt) . '"}]}'

    try {
        http := ComObject("WinHTTP.WinHTTPrequest.5.1")
        http.Open("POST", "https://api.anthropic.com/v1/messages", false)
        http.SetRequestHeader("Content-Type",      "application/json")
        http.SetRequestHeader("x-api-key",         g_apiKey)
        http.SetRequestHeader("anthropic-version", "2023-06-01")
        http.Send(body)
        return ExtractAPIText(http.ResponseText)
    } catch as e {
        return ""
    }
}

; ─── Minimal JSON string escaper ─────────────────────────────
EscapeJSON(str) {
    str := StrReplace(str, "\",  "\\")
    str := StrReplace(str, '"',  '\"')
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "")
    str := StrReplace(str, "`t", "\t")
    return str
}

; ─── Extract first text block from Claude API JSON response ──
ExtractAPIText(json) {
    ; Look for "text":"..." in the response content array
    pos := InStr(json, '"text":"')
    if !pos
        return ""
    pos   += 8
    result := ""
    loop {
        if (pos > StrLen(json))
            break
        ch := SubStr(json, pos, 1)
        if (ch = '"')
            break
        if (ch = "\") {
            pos++
            nc := SubStr(json, pos, 1)
            result .= (nc = "n") ? "`n"
                    : (nc = "t") ? "`t"
                    : (nc = '"') ? '"'
                    : nc
        } else {
            result .= ch
        }
        pos++
    }
    return result
}

; ════════════════════════════════════════════════════════════
;  TYPING SESSION MANAGEMENT
; ════════════════════════════════════════════════════════════

StartTyping(*) {
    global g_text, g_state, g_stop, g_pause, g_mode
    global g_charsOut, g_wordsOut, g_startTime, g_totalCh

    if (g_state = "typing" || g_state = "countdown")
        return

    ; Determine text source: queued text → preview box → clipboard
    if (StrLen(g_text) = 0)
        g_text := Preview.Value
    if (StrLen(g_text) = 0) {
        RefreshPreview()
        g_text := Preview.Value
    }
    if (StrLen(g_text) = 0) {
        MsgBox("Nothing to type.`nPaste or type in the preview box, or copy text to clipboard.",
            "Paste Bypass", 0x30)
        return
    }

    if (g_mode = "CS")
        g_text := NormalizeCode(g_text)

    g_stop      := false
    g_pause     := false
    g_charsOut  := 0
    g_wordsOut  := 0
    g_totalCh   := StrLen(g_text)

    LblChars.Value    := "0 / " . g_totalCh
    LblWords.Value    := "0"
    LblCurWpm.Value   := WpmSlider.Value . " WPM"
    LblETA.Value      := "—"
    ProgressBar.Value := 0

    BtnStart.Enabled  := false
    BtnPause.Enabled  := false
    BtnResume.Enabled := false
    BtnStop.Enabled   := true

    LockTarget()
    SetNoActivate(true)
    SetState("countdown")
    SetTimer(RunTypingSession, -1)
}

PauseTyping(*) {
    global g_pause, g_state
    if (g_state != "typing")
        return
    g_pause := true
    g_state := "paused"
    BtnPause.Enabled  := false
    BtnResume.Enabled := true
    SetState("paused")
}

ResumeTyping(*) {
    global g_pause, g_state
    if (g_state != "paused")
        return
    g_pause := false
    g_state := "typing"
    if (g_targetWin && WinExist("ahk_id " . g_targetWin))
        WinActivate("ahk_id " . g_targetWin)
    BtnPause.Enabled  := true
    BtnResume.Enabled := false
    SetState("typing")
}

StopTyping(*) {
    global g_stop, g_pause, g_state, g_text
    g_stop  := true
    g_pause := false
    g_state := "stopped"
    g_text  := ""
    SetNoActivate(false)
    UnlockTarget()
    ResetButtons()
    SetState("stopped")
    LblCurWpm.Value   := WpmSlider.Value . " WPM"
    LblETA.Value      := "—"
    ProgressBar.Value := 0
    MyGui.Show()
}

TogglePause(*) {
    global g_state
    if (g_state = "typing") {
        PauseTyping()
    } else if (g_state = "paused") {
        ResumeTyping()
    }
}

ResetButtons() {
    BtnStart.Enabled  := true
    BtnPause.Enabled  := false
    BtnResume.Enabled := false
    BtnStop.Enabled   := false
}

; ════════════════════════════════════════════════════════════
;  CORE TYPING LOOP  (timer-fired thread)
; ════════════════════════════════════════════════════════════
RunTypingSession() {
    global g_state, g_stop, g_pause, g_text, g_mode
    global g_charsOut, g_wordsOut, g_startTime, g_totalCh, g_targetWin

    ; ── 3-second countdown ───────────────────────────────────
    loop 3 {
        LblState.Value := "Starting in " . (4 - A_Index) . "…"
        Sleep(1000)
        if g_stop {
            SetNoActivate(false)
            UnlockTarget()
            ResetButtons()
            SetState("idle")
            return
        }
    }

    ; ── Activate target window ───────────────────────────────
    if (g_targetWin && WinExist("ahk_id " . g_targetWin))
        WinActivate("ahk_id " . g_targetWin)
    Sleep(200)

    ; ── Check keystroke permissions ──────────────────────────
    if (g_targetWin && !WinActive("ahk_id " . g_targetWin)) {
        if !A_IsAdmin {
            MsgBox("Paste Bypass cannot send keystrokes to this window.`n`n"
                . "This usually happens when the target app runs as administrator.`n`n"
                . "Fix: right-click PasteBypass.exe → 'Run as administrator'`n"
                . "(Only do this if this message keeps appearing.)",
                "Paste Bypass — Permission Issue", 0x30)
        }
        SetNoActivate(false)
        UnlockTarget()
        ResetButtons()
        SetState("idle")
        return
    }

    ; ── Session starts ───────────────────────────────────────
    g_state     := "typing"
    g_startTime := A_TickCount
    SetState("typing")
    BtnPause.Enabled := true

    ; Capture toggles at session start (WPM is re-read per char)
    humanize  := ChkHuman.Value
    doMistake := ChkMist.Value
    mistRate  := MistFreqHigh.Value ? 0.10 : (MistFreqMed.Value ? 0.05 : 0.02)

    if (g_mode = "CS")
        TypeCode(humanize, doMistake, mistRate)
    else
        TypeProse(humanize, doMistake, mistRate)

    ; ── Done ─────────────────────────────────────────────────
    if (!g_stop) {
        g_wordsOut++
        g_state := "done"
        SetState("done")
        LblETA.Value      := "Done!"
        LblChars.Value    := g_totalCh . " / " . g_totalCh
        LblWords.Value    := g_wordsOut
        ProgressBar.Value := 100
        g_text            := ""
    }

    SetNoActivate(false)
    UnlockTarget()
    ResetButtons()
    MyGui.Show()
}

; ════════════════════════════════════════════════════════════
;  TYPING ENGINES
; ════════════════════════════════════════════════════════════

; ─── EN mode: plain character stream ─────────────────────────
TypeProse(humanize, doMistake, mistRate) {
    global g_charsOut
    loop parse, g_text {
        if !CheckRunning()
            return
        ch := A_LoopField
        if (ch = "`r")
            continue
        if (ch = "`n") {
            Send("{Enter}")
            g_charsOut++
            Sleep(humanize ? Random(180, 380) : GetBaseDelay())
            continue
        }
        TypeChar(ch, humanize, doMistake, mistRate)
    }
}

; ─── CS mode: line-by-line, editor-proof ─────────────────────
; NOTE: never send {Esc} here — newer Ace (CodeHS) treats Esc as
; "leave the editor", and the next Enter only refocuses it.
; Sentinel is "~" (not "_") so it never opens autocomplete.
; Code editors (CodeHS/Ace, Monaco, CodeMirror) fight a keystroke
; stream in two ways:
;   1. Auto-close: typing ( [ { " ' inserts the closer too.
;   2. Auto-indent: Enter / } / : rewrite the line's leading whitespace.
; Since every character is typed left-to-right, anything the editor
; auto-inserts always sits to the RIGHT of the cursor, and auto-indent
; only ever touches LEADING whitespace. So for each line we:
;   type the content (no indent) → delete everything right of the cursor
;   → replace the leading whitespace with the original indentation.
TypeCode(humanize, doMistake, mistRate) {
    global g_charsOut
    lines := StrSplit(g_text, "`n")

    for i, line in lines {
        if !CheckRunning()
            return

        RegExMatch(line, "^ *", &m)
        indent  := m[0]
        content := SubStr(line, StrLen(indent) + 1)

        if (i > 1) {
            CodeKey("{Enter}")
            g_charsOut++
            Sleep(humanize ? Random(180, 380) : GetBaseDelay())
        }

        ; Blank line: leave it. Any auto-indent left here is invisible, and
        ; select-to-line-start + delete is too destructive if an Enter misfires.
        if (content = "")
            continue

        loop parse, content {
            if !CheckRunning()
                return
            TypeChar(A_LoopField, humanize, doMistake, mistRate)
        }

        ; 1. Drop auto-inserted closers. Typing a space over the selection
        ;    then deleting it works even when the selection is empty
        ;    (a bare Delete would merge the next line up).
        CodeKey("+{End}")
        CodeKey("{Space}")
        CodeKey("{Backspace}")

        ; 2. Force the original indentation. Home → first non-space char,
        ;    Shift+Home → select the editor's indent (empty if none).
        ;    "~" replaces the selection, Backspace clears it, then type ours.
        CodeKey("{Home}")
        CodeKey("+{Home}")
        CodeKey("~")
        CodeKey("{Backspace}")
        if (indent != "") {
            Send("{Raw}" . indent)
            Sleep(CODE_KEY_DELAY)
            g_charsOut += StrLen(indent)
        }
        CodeKey("{End}")
    }
}

; ─── Waits out a pause and refocuses the target. False = stopped ─
CheckRunning() {
    global g_stop, g_pause, g_targetWin
    if g_stop
        return false
    while g_pause
        Sleep(50)
    if g_stop
        return false
    ; Re-activate target if focus was stolen (safety net)
    try {
        if (g_targetWin && WinGetID("A") != g_targetWin)
            WinActivate("ahk_id " . g_targetWin)
    }
    return true
}

; ─── Type one character with speed / humanize / mistake rules ─
TypeChar(ch, humanize, doMistake, mistRate) {
    global g_charsOut, g_wordsOut
    baseDelay := GetBaseDelay()

    if (doMistake && Random(0.0, 1.0) < mistRate) {
        wrong := NearbyKey(ch)
        if (wrong != ch) {
            Send("{Raw}" . wrong)
            Sleep(Random(150, 350))
            Send("{Backspace}")
            Sleep(Random(80, 170))
        }
    }

    Send("{Raw}" . ch)
    g_charsOut++
    if (ch = " ")
        g_wordsOut++

    delay := baseDelay
    if humanize {
        delay := Max(10, Round(baseDelay * (1.0 + Random(-25, 25) / 100.0)))
        if (ch = " ")
            delay += Random(30, 140)
        if (ch = "." || ch = "!" || ch = "?")
            delay += Random(120, 340)
        else if (ch = ",")
            delay += Random(40, 120)
    }
    Sleep(delay)
}

; Re-read WPM live — slider changes apply immediately
GetBaseDelay() => Round(12000 / Max(WpmSlider.Value, 1))   ; 60000ms / (wpm × 5 chars/word)

CodeKey(keys) {
    Send(keys)
    Sleep(CODE_KEY_DELAY)
}

; ─── Clean up code before typing ─────────────────────────────
; Tabs → 4 spaces, non-breaking spaces (from web copies) → spaces,
; trailing whitespace and trailing blank lines removed.
NormalizeCode(code) {
    code := StrReplace(code, "`r")
    code := StrReplace(code, "`t", "    ")
    code := StrReplace(code, Chr(160), " ")
    out := ""
    for i, ln in StrSplit(code, "`n")
        out .= (i > 1 ? "`n" : "") . RTrim(ln, " ")
    return RTrim(out, "`n")
}

; ════════════════════════════════════════════════════════════
;  SHARED HELPERS
; ════════════════════════════════════════════════════════════

NearbyKey(ch) {
    lower := StrLower(ch)
    if NEARBY.Has(lower) {
        n := NEARBY[lower]
        return SubStr(n, Random(1, StrLen(n)), 1)
    }
    return ch
}

UpdateProgress() {
    global g_state, g_charsOut, g_wordsOut, g_startTime, g_totalCh
    if (g_state != "typing" && g_state != "paused")
        return

    pct := (g_totalCh > 0) ? Round(g_charsOut / g_totalCh * 100) : 0
    ProgressBar.Value := Min(pct, 100)
    LblChars.Value    := g_charsOut . " / " . g_totalCh
    LblWords.Value    := g_wordsOut

    elapsed := (A_TickCount - g_startTime) / 60000.0
    if (elapsed > 0.005 && g_wordsOut > 0)
        LblCurWpm.Value := Round(g_wordsOut / elapsed) . " WPM (actual)"

    if (g_charsOut > 0 && elapsed > 0.005 && g_totalCh > g_charsOut) {
        rate   := g_charsOut / elapsed
        etaSec := Round((g_totalCh - g_charsOut) / rate * 60)
        if (etaSec < 0) etaSec := 0
        LblETA.Value := (etaSec >= 60)
            ? (etaSec // 60) . "m " . Mod(etaSec, 60) . "s"
            : etaSec . "s"
    }
}

UpdateWpmLabel(*) {
    v := WpmSlider.Value
    WpmLabel.Value  := v . " WPM"
    LblCurWpm.Value := v . " WPM"
}

SetState(s) {
    switch s {
        case "idle":      LblState.Value := "Idle"
        case "countdown": LblState.Value := "Counting down…"
        case "typing":    LblState.Value := "Typing"
        case "paused":    LblState.Value := "Paused"
        case "stopped":   LblState.Value := "Stopped"
        case "done":      LblState.Value := "Completed"
        default:          LblState.Value := s
    }
}

ShowTip(msg) {
    ToolTip(msg)
    SetTimer(() => ToolTip(""), -2500)
}

; ── Window-focus helpers ──────────────────────────────────────

TrackTargetWindow() {
    global g_targetWin
    try {
        hwnd := WinGetID("A")
        if (hwnd != MyGui.Hwnd)
            g_targetWin := hwnd
    }
}

LockTarget() {
    global g_targetWin
    SetTimer(TrackTargetWindow, 0)
    currentActive := WinGetID("A")
    if (currentActive != MyGui.Hwnd)
        g_targetWin := currentActive
}

UnlockTarget() {
    SetTimer(TrackTargetWindow, 200)
}

SetNoActivate(enable) {
    exStyle := WinGetExStyle("ahk_id " . MyGui.Hwnd)
    if enable
        WinSetExStyle(exStyle | WS_EX_NOACTIVATE,  "ahk_id " . MyGui.Hwnd)
    else
        WinSetExStyle(exStyle & ~WS_EX_NOACTIVATE, "ahk_id " . MyGui.Hwnd)
}

; ── Desktop shortcut for taskbar pinning ─────────────────────
CreateShortcutIfNeeded() {
    path := A_Desktop . "\Paste Bypass.lnk"
    if FileExist(path)
        return
    try {
        shell := ComObject("WScript.Shell")
        lnk   := shell.CreateShortcut(path)
        if A_IsCompiled {
            ; Running as compiled .exe — point shortcut directly at it
            lnk.TargetPath   := A_ScriptFullPath
            lnk.Arguments    := ""
            lnk.IconLocation := A_ScriptFullPath . ",0"
        } else {
            ; Running as .ahk — launch via AutoHotkey interpreter
            lnk.TargetPath   := A_AhkPath
            lnk.Arguments    := '"' . A_ScriptFullPath . '"'
            lnk.IconLocation := A_AhkPath . ",0"
        }
        lnk.WorkingDirectory := A_ScriptDir
        lnk.Description      := "Paste Bypass Auto Typer"
        lnk.Save()
    }
}

; ── Create config INI with defaults if it does not exist ─────
EnsureConfigExists() {
    if FileExist(CFG_FILE)
        return
    try {
        IniWrite("", CFG_FILE, "API", "ClaudeKey")
    } catch as e {
        MsgBox("Could not create config file:`n" . CFG_FILE
            . "`n`nMake sure the app folder is not read-only."
            . "`nSettings will not be saved this session.",
            "Paste Bypass — Config Error", 0x30)
    }
}
