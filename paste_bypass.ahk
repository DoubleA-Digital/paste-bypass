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

; ─── Auto-pair close characters for Brace-Safe mode ─────────
global PAIR_CLOSE := Map("(",")", "[","]", "{","}", '"','"', "'","'")
global PAIR_OPEN  := Map(")","(", "]","[", "}","{", '"','"', "'","'")

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
global g_skipStack  := ""       ; Brace-Safe pair-skip stack (string, last char = top)
global WS_EX_NOACTIVATE := 0x08000000

; ─── Config file (persists API key) ──────────────────────────
global CFG_FILE := A_ScriptDir . "\paste_bypass_config.ini"
global g_apiKey := IniRead(CFG_FILE, "API", "ClaudeKey", "")

; ─── Control-group arrays for show/hide on mode switch ───────
global CS_Controls := []
global EN_Controls := []

; ─── Shortcut on first run ───────────────────────────────────
CreateShortcutIfNeeded()

; ════════════════════════════════════════════════════════════
;  BUILD GUI  (dark theme  #1e1e2e)
; ════════════════════════════════════════════════════════════
global MyGui := Gui("+AlwaysOnTop", "Paste Bypass — Auto Typer")
MyGui.BackColor := "1e1e2e"
MyGui.SetFont("s10 q5 cF8F8F2", "Segoe UI")
MyGui.OnEvent("Close", (*) => ExitApp())

; ── Title ────────────────────────────────────────────────────
MyGui.SetFont("s14 Bold cF8F8F2")
MyGui.Add("Text", "x16 y12 w390 Center", "Paste Bypass")
MyGui.SetFont("s9 c888899")
MyGui.Add("Text", "x16 y36 w390 Center", "Auto-types text with human-like behaviour")

; ── Section 1: Mode Selection ─────────────────────────────────
MyGui.SetFont("s8 Bold c888899")
MyGui.Add("Text", "x16 y64", "1  MODE SELECTION")
MyGui.SetFont("s10 cF8F8F2")
global RadioCS := MyGui.Add("Radio",
    "x16 y80 w195 cF8F8F2 Background1e1e2e +Checked", " Computer Science")
global RadioEN := MyGui.Add("Radio",
    "x215 y80 w185 cF8F8F2 Background1e1e2e", " English / Writing")
MyGui.SetFont("s8 c555566")
MyGui.Add("Text", "x16 y101",
    "CS = code typing, brace-safe, Java tools     EN = essays, humanize, grammar polish")
RadioCS.OnEvent("Click", SwitchMode)
RadioEN.OnEvent("Click", SwitchMode)
MyGui.Add("Text", "x16 y118 w390 h1 +0x10")

; ── Section 2: Text / Clipboard Preview ───────────────────────
MyGui.SetFont("s8 Bold c888899")
MyGui.Add("Text", "x16 y126", "2  TEXT / CLIPBOARD PREVIEW  (editable)")
MyGui.SetFont("s9 cF8F8F2")
global Preview := MyGui.Add("Edit",
    "x16 y142 w390 h78 +Multi +VScroll +Background2a2a3e")
; Preview button row
global BtnRefresh := MyGui.Add("Button", "x16  y224 w88  h22", "Refresh")
global BtnClear   := MyGui.Add("Button", "x110 y224 w70  h22", "Clear")
global BtnUseText := MyGui.Add("Button", "x186 y224 w112 h22", "Use This Text")
global BtnCopyPrv := MyGui.Add("Button", "x304 y224 w102 h22", "Copy Preview")
BtnRefresh.OnEvent("Click", RefreshPreview)
BtnClear.OnEvent("Click",   ClearPreview)
BtnUseText.OnEvent("Click", LoadPreviewText)
BtnCopyPrv.OnEvent("Click", CopyPreview)
MyGui.SetFont("s8 c555566")
MyGui.Add("Text", "x16 y250",
    "Refresh = load clipboard   Use This Text = queue for typing   Copy Preview = copy box to clipboard")
MyGui.Add("Text", "x16 y264 w390 h1 +0x10")

; ════════════════════════════════════════════════════════════
;  Section 3a: CODE TOOLS  (Computer Science Mode)
;  These controls are hidden in English mode.
; ════════════════════════════════════════════════════════════
MyGui.SetFont("s8 Bold c888899")
global t_CS_Hdr := MyGui.Add("Text", "x16 y272", "3  CODE TOOLS")
CS_Controls.Push(t_CS_Hdr)

; CodeHS Brace-Safe toggle
MyGui.SetFont("s10 cF8F8F2")
global ChkBraceSafe := MyGui.Add("CheckBox",
    "x16 y288 w300 +Checked cF8F8F2 Background1e1e2e", " CodeHS Brace-Safe Mode")
CS_Controls.Push(ChkBraceSafe)
MyGui.SetFont("s8 c888899")
global t_BraceHint := MyGui.Add("Text", "x34 y307",
    "Skips auto-inserted closing chars so the editor does not duplicate them")
CS_Controls.Push(t_BraceHint)

; No Extra Wrapper / Paste Body Only
MyGui.SetFont("s10 cF8F8F2")
global ChkNoWrapper := MyGui.Add("CheckBox",
    "x16 y326 w340 cF8F8F2 Background1e1e2e",
    " No Extra Method/Class Wrapper  (CodeHS already has the signature)")
CS_Controls.Push(ChkNoWrapper)
global ChkBodyOnly := MyGui.Add("CheckBox",
    "x16 y346 w340 cF8F8F2 Background1e1e2e",
    " Paste Body Only  (strips outermost method/class braces)")
CS_Controls.Push(ChkBodyOnly)

; Format Code button
global BtnFmt := MyGui.Add("Button", "x16 y368 w120 h26", "Format Code")
CS_Controls.Push(BtnFmt)
BtnFmt.OnEvent("Click", FormatCode)
MyGui.SetFont("s8 c555566")
global t_FmtHint := MyGui.Add("Text", "x142 y372",
    "Normalises indentation to 4 spaces before typing")
CS_Controls.Push(t_FmtHint)

global CS_Sep := MyGui.Add("Text", "x16 y400 w390 h1 +0x10")
CS_Controls.Push(CS_Sep)

; ════════════════════════════════════════════════════════════
;  Section 3b: ENGLISH TOOLS  (English Mode)
;  These controls are hidden in CS mode.
; ════════════════════════════════════════════════════════════
MyGui.SetFont("s8 Bold c888899")
global t_EN_Hdr := MyGui.Add("Text", "x16 y272", "3  ENGLISH TOOLS")
t_EN_Hdr.Visible := false
EN_Controls.Push(t_EN_Hdr)

; Simple / Strong style
MyGui.SetFont("s9 c888899")
global t_StyleLbl := MyGui.Add("Text", "x16 y290 w55", "Style:")
t_StyleLbl.Visible := false
EN_Controls.Push(t_StyleLbl)
MyGui.SetFont("s9 cF8F8F2")
global RadioSimple := MyGui.Add("Radio",
    "x72 y289 w90 cF8F8F2 Background1e1e2e +Checked", " Simple")
RadioSimple.Visible := false
EN_Controls.Push(RadioSimple)
global RadioStrong := MyGui.Add("Radio",
    "x168 y289 w100 cF8F8F2 Background1e1e2e", " Strong / Academic")
RadioStrong.Visible := false
EN_Controls.Push(RadioStrong)
MyGui.SetFont("s8 c555566")
global t_StyleHint := MyGui.Add("Text", "x16 y308",
    "Simple = natural student writing     Strong = polished, academic tone")
t_StyleHint.Visible := false
EN_Controls.Push(t_StyleHint)

; Action buttons
MyGui.SetFont("s10 cF8F8F2")
global BtnHumanize := MyGui.Add("Button", "x16  y326 w140 h28", "Humanize Text")
BtnHumanize.Visible := false
BtnHumanize.OnEvent("Click", HumanizeText)
EN_Controls.Push(BtnHumanize)
global BtnPolish := MyGui.Add("Button", "x164 y326 w140 h28", "Polish Grammar")
BtnPolish.Visible := false
BtnPolish.OnEvent("Click", PolishGrammar)
EN_Controls.Push(BtnPolish)
global BtnRevert := MyGui.Add("Button", "x312 y326 w94 h28", "Revert")
BtnRevert.Visible := false
BtnRevert.OnEvent("Click", RevertText)
EN_Controls.Push(BtnRevert)

; API key field
MyGui.SetFont("s8 c888899")
global t_ApiLbl := MyGui.Add("Text", "x16 y362 w90", "Claude API Key:")
t_ApiLbl.Visible := false
EN_Controls.Push(t_ApiLbl)
MyGui.SetFont("s9 cF8F8F2")
global TxtApiKey := MyGui.Add("Edit",
    "x110 y359 w296 h22 +Password +Background2a2a3e", g_apiKey)
TxtApiKey.Visible := false
TxtApiKey.OnEvent("Change", SaveApiKey)
EN_Controls.Push(TxtApiKey)

global EN_Sep := MyGui.Add("Text", "x16 y390 w390 h1 +0x10")
EN_Sep.Visible := false
EN_Controls.Push(EN_Sep)

; ── Section 4: Typing Speed ───────────────────────────────────
MyGui.SetFont("s8 Bold c888899")
MyGui.Add("Text", "x16 y408", "4  TYPING SPEED — WORDS PER MINUTE")
MyGui.SetFont("s10 cF8F8F2")
global WpmSlider := MyGui.Add("Slider",
    "x16 y424 w320 h30 Range10-300 TickInterval50 Line5 Page20", 80)
WpmSlider.OnEvent("Change", UpdateWpmLabel)
global WpmLabel := MyGui.Add("Text", "x344 y430 w62 Right", "80 WPM")
MyGui.SetFont("s8 c555566")
MyGui.Add("Text", "x16 y458", "Slow (20)                 Normal (80)                 Fast (200+)")

; ── Section 5: Humanization & Mistakes ───────────────────────
MyGui.SetFont("s8 Bold c888899")
MyGui.Add("Text", "x16 y480", "5  HUMANIZATION & MISTAKES")
MyGui.SetFont("s10 cF8F8F2")
global ChkHuman := MyGui.Add("CheckBox",
    "x16 y496 w230 +Checked cF8F8F2 Background1e1e2e", " Humanized Typing")
MyGui.SetFont("s8 c888899")
MyGui.Add("Text", "x34 y515", "Random pauses between words and after punctuation")
MyGui.SetFont("s10 cF8F8F2")
global ChkMist := MyGui.Add("CheckBox",
    "x16 y534 w230 cF8F8F2 Background1e1e2e", " Typing Mistakes")
MyGui.SetFont("s8 c888899")
MyGui.Add("Text", "x34 y553", "Wrong key → pause → backspace → correct key")
MyGui.Add("Text", "x34 y570", "Frequency:")
MyGui.SetFont("s9 cF8F8F2")
global MistFreqLow  := MyGui.Add("Radio",
    "x101 y569 w52 cF8F8F2 Background1e1e2e +Checked", " Low")
global MistFreqMed  := MyGui.Add("Radio",
    "x156 y569 w65 cF8F8F2 Background1e1e2e", " Medium")
global MistFreqHigh := MyGui.Add("Radio",
    "x224 y569 w55 cF8F8F2 Background1e1e2e", " High")
MyGui.Add("Text", "x16 y592 w390 h1 +0x10")

; ── Section 6: Controls ───────────────────────────────────────
MyGui.SetFont("s8 Bold c888899")
MyGui.Add("Text", "x16 y600", "6  CONTROLS")
MyGui.SetFont("s10 Bold cF8F8F2")
global BtnStart  := MyGui.Add("Button", "x16  y616 w88  h34", "Start")
global BtnPause  := MyGui.Add("Button", "x112 y616 w88  h34", "Pause")
global BtnResume := MyGui.Add("Button", "x208 y616 w88  h34", "Resume")
global BtnStop   := MyGui.Add("Button", "x304 y616 w100 h34", "Stop")
BtnPause.Enabled  := false
BtnResume.Enabled := false
BtnStop.Enabled   := false
BtnStart.OnEvent("Click",  StartTyping)
BtnPause.OnEvent("Click",  PauseTyping)
BtnResume.OnEvent("Click", ResumeTyping)
BtnStop.OnEvent("Click",   StopTyping)

; ── Section 7: Status & Progress ─────────────────────────────
MyGui.SetFont("s8 Bold c888899")
MyGui.Add("Text", "x16 y662", "7  STATUS & PROGRESS")
MyGui.SetFont("s9 c888899")
MyGui.Add("Text", "x16 y680 w92", "State:")
MyGui.Add("Text", "x16 y699 w92", "Target WPM:")
MyGui.Add("Text", "x16 y718 w92", "Characters:")
MyGui.Add("Text", "x16 y737 w92", "Words:")
MyGui.Add("Text", "x16 y756 w92", "Time left:")
MyGui.SetFont("s9 Bold cF8F8F2")
global LblState  := MyGui.Add("Text", "x112 y680 w200", "Idle")
global LblCurWpm := MyGui.Add("Text", "x112 y699 w200", "80 WPM")
global LblChars  := MyGui.Add("Text", "x112 y718 w200", "0")
global LblWords  := MyGui.Add("Text", "x112 y737 w200", "0")
global LblETA    := MyGui.Add("Text", "x112 y756 w200", "—")
global ProgressBar := MyGui.Add("Progress",
    "x16 y780 w390 h16 cGreen Background2a2a3e", 0)
MyGui.SetFont("s8 c444455")
MyGui.Add("Text", "x16 y804 w390 Center",
    "Ctrl+Shift+V = Start   *   Esc = Emergency Stop   *   Ctrl+Shift+P = Pause/Resume")

MyGui.Show("w422 h826")
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

#HotIf (g_state = "typing" || g_state = "paused" || g_state = "countdown")
Escape::StopTyping()
#HotIf

; ════════════════════════════════════════════════════════════
;  MODE MANAGEMENT
; ════════════════════════════════════════════════════════════

SwitchMode(*) {
    global g_mode
    isCS   := RadioCS.Value
    g_mode := isCS ? "CS" : "EN"

    ; Toggle visibility of each section's controls
    for ctrl in CS_Controls
        ctrl.Visible := isCS
    for ctrl in EN_Controls
        ctrl.Visible := !isCS

    ; Apply mode-specific defaults
    if isCS {
        ChkMist.Value  := 0   ; mistakes off — code must be exact
        ChkHuman.Value := 0   ; no humanization for code
    } else {
        ChkHuman.Value := 1   ; humanized timing on for prose
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

; ─── Strip outermost method/class body for Paste Body Only ───
StripOuterWrapper(code) {
    lines     := StrSplit(code, "`n")
    n         := lines.Length
    firstLine := 0
    lastLine  := 0

    ; Find first declaration line that contains an opening brace
    i := 1
    while (i <= n) {
        t := Trim(lines[i])
        if (InStr(t, "{") && RegExMatch(t, "i)public|private|protected|static|void|class")) {
            firstLine := i
            break
        }
        i++
    }
    if (firstLine = 0)
        return code

    ; Walk characters to find the matching closing brace
    depth   := 0
    lineIdx := firstLine
    while (lineIdx <= n) {
        txt  := lines[lineIdx]
        cLen := StrLen(txt)
        cIdx := 1
        while (cIdx <= cLen) {
            c := SubStr(txt, cIdx, 1)
            if (c = "{")
                depth++
            if (c = "}")
                depth--
            if (depth = 0 && lineIdx > firstLine) {
                lastLine := lineIdx
                break
            }
            cIdx++
        }
        if (lastLine > 0)
            break
        lineIdx++
    }

    if (lastLine = 0 || lastLine <= firstLine)
        return code

    ; Extract inner lines and remove one level of indentation
    inner  := ""
    indent := "    "
    idx    := firstLine + 1
    while (idx <= lastLine - 1) {
        ln := lines[idx]
        if (SubStr(ln, 1, 4) = indent)
            ln := SubStr(ln, 5)
        inner .= ln . (idx < lastLine - 1 ? "`n" : "")
        idx++
    }
    return inner
}

; ─── No-Wrapper: strip first method/class signature line ─────
StripSignature(code) {
    lines  := StrSplit(code, "`n")
    n      := lines.Length
    result := ""
    skip   := true    ; skip until we find the opening {

    i := 1
    while (i <= n) {
        ln := lines[i]
        if skip {
            ; Stop skipping once we have consumed the opening {
            if InStr(ln, "{")
                skip := false
            i++
            continue
        }
        result .= ln . (i < n ? "`n" : "")
        i++
    }

    ; Remove last line if it is just a closing brace
    trimEnd := RTrim(result)
    if (SubStr(trimEnd, StrLen(trimEnd)) = "}")
        result := RTrim(SubStr(trimEnd, 1, StrLen(trimEnd) - 1), "`n")

    return Trim(result, "`n")
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
    global g_text, g_state, g_stop, g_pause, g_mode, g_skipStack
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

    ; Apply CS-mode pre-processing to the text
    if (g_mode = "CS") {
        if (ChkBodyOnly.Value)
            g_text := StripOuterWrapper(g_text)
        if (ChkNoWrapper.Value)
            g_text := StripSignature(g_text)
    }

    g_stop      := false
    g_pause     := false
    g_charsOut  := 0
    g_wordsOut  := 0
    g_totalCh   := StrLen(g_text)
    g_skipStack := ""

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
    global g_state, g_stop, g_pause, g_text, g_mode, g_skipStack
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

    ; ── Session starts ───────────────────────────────────────
    g_state     := "typing"
    g_startTime := A_TickCount
    SetState("typing")
    BtnPause.Enabled := true

    ; Capture toggles at session start (WPM is re-read per char)
    humanize    := ChkHuman.Value
    doMistake   := ChkMist.Value
    braceSafe   := (g_mode = "CS") && ChkBraceSafe.Value
    mistRate    := MistFreqHigh.Value ? 0.10 : (MistFreqMed.Value ? 0.05 : 0.02)

    ; ── Per-character loop ────────────────────────────────────
    loop parse, g_text {

        if g_stop
            break

        while g_pause
            Sleep(50)
        if g_stop
            break

        ; Re-activate target if focus was stolen (safety net)
        if (g_targetWin && WinGetID("A") != g_targetWin)
            WinActivate("ahk_id " . g_targetWin)

        ; Re-read WPM live — slider changes apply immediately
        wpm       := Max(WpmSlider.Value, 1)
        baseDelay := Round(12000 / wpm)   ; 60000ms / (wpm × 5 chars/word)

        ch := A_LoopField

        if (ch = "`r")
            continue

        ; ── Newline ──────────────────────────────────────────
        if (ch = "`n") {
            Send("{Enter}")
            g_charsOut++
            Sleep(humanize ? Random(180, 380) : baseDelay)
            continue
        }

        ; ── Brace-Safe: skip auto-inserted closing chars ─────
        ; Only active in CS mode. Applies to ) ] " ' (not {} which
        ; span multiple lines and are handled by the editor's smart indent).
        if braceSafe {
            action := BraceSafeHandle(ch)
            if (action = "skip") {
                ; Editor already has this closing char — move cursor past it
                Send("{Right}")
                continue
            }
            ; action = "type" — fall through to normal typing
        }

        ; ── Typing mistake simulation (English mode or if enabled in CS) ──
        if (doMistake && Random(0.0, 1.0) < mistRate) {
            wrong := NearbyKey(ch)
            if (wrong != ch) {
                Send("{Raw}" . wrong)
                Sleep(Random(150, 350))
                Send("{Backspace}")
                Sleep(Random(80, 170))
            }
        }

        ; ── Type the character ───────────────────────────────
        Send("{Raw}" . ch)
        g_charsOut++

        if (ch = " " || ch = "`t")
            g_wordsOut++

        ; ── Delay ────────────────────────────────────────────
        delay := baseDelay
        if humanize {
            delay := Max(10, Round(baseDelay * (1.0 + Random(-25, 25) / 100.0)))
            if (ch = " " || ch = "`t")
                delay += Random(30, 140)
            if (ch = "." || ch = "!" || ch = "?")
                delay += Random(120, 340)
            else if (ch = ",")
                delay += Random(40, 120)
        }
        Sleep(delay)
    }

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
;  BRACE-SAFE HELPER
; ════════════════════════════════════════════════════════════

; Called for every character in CS + Brace-Safe mode.
; Returns "skip"  — caller should press Right and not type ch
; Returns "type"  — caller should type ch normally
BraceSafeHandle(ch) {
    global g_skipStack

    ; For opening brackets: type normally but push expected close to stack
    if (ch = "(" || ch = "[" || ch = '"' || ch = "'") {
        ; If this is a closing quote and it matches stack top, skip it
        if ((ch = '"' || ch = "'") && StrLen(g_skipStack) > 0
            && SubStr(g_skipStack, -1) = ch) {
            g_skipStack := SubStr(g_skipStack, 1, StrLen(g_skipStack) - 1)
            return "skip"
        }
        ; Otherwise it's an opener — push expected close
        g_skipStack .= PAIR_CLOSE[ch]
        return "type"
    }

    ; For closing brackets: skip if expected (auto-inserted by editor)
    if (ch = ")" || ch = "]") {
        if (StrLen(g_skipStack) > 0 && SubStr(g_skipStack, -1) = ch) {
            g_skipStack := SubStr(g_skipStack, 1, StrLen(g_skipStack) - 1)
            return "skip"
        }
    }

    ; { and } are typed normally — CodeMirror's smart indent handles them
    return "type"
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
        lnk.TargetPath       := A_AhkPath
        lnk.Arguments        := '"' . A_ScriptFullPath . '"'
        lnk.WorkingDirectory := A_ScriptDir
        lnk.IconLocation     := A_AhkPath . ",0"
        lnk.Description      := "Paste Bypass Auto Typer"
        lnk.Save()
    }
}
