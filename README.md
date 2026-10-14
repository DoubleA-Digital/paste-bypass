# Paste Bypass — Auto Typer

An AutoHotkey v2 script that types clipboard or preview-box text character-by-character with human-like behaviour.  
Built for bypassing paste-disabled fields (e.g. CodeHS, online exams) and essay submission sites.

> **Windows only.** AutoHotkey v2 is a Windows-exclusive program. It does not run on Mac or Chromebook (see [Why Windows only?](#why-windows-only) below).

---

## Distribution Folder Structure

When you share or move the app, keep these three files together in one folder:

```
PasteBypass/
├── PasteBypass.exe          ← compiled app (share this)
├── paste_bypass_config.ini  ← your saved settings (API key etc.)
└── README.md                ← this file
```

The config file is created automatically the first time you run the app. Copy the whole folder to move your settings to another PC.

---

## Running from Source (.ahk)

1. Install [AutoHotkey v2](https://www.autohotkey.com/) (free, Windows only)
2. Double-click `paste_bypass.ahk`

---

## Compiling to a Standalone .exe

You do **not** need AutoHotkey installed on the target PC if you compile first.

### Steps

1. Install [AutoHotkey v2](https://www.autohotkey.com/) on your own PC.
2. Right-click `paste_bypass.ahk` → **Compile Script**  
   *(if you don't see this option, open the AutoHotkey v2 installation folder and run `Ahk2Exe.exe` manually)*
3. In the Ahk2Exe window:
   - **Source:** browse to `paste_bypass.ahk`
   - **Destination:** leave blank — it will save `PasteBypass.exe` in the same folder automatically
   - Click **Convert**
4. You will find `PasteBypass.exe` next to the `.ahk` file.

### Moving to another Windows device

1. Create a folder called `PasteBypass` anywhere (Desktop, USB drive, etc.)
2. Copy into it:
   - `PasteBypass.exe`
   - `paste_bypass_config.ini` *(if you want to carry your API key)*
   - `README.md` *(optional)*
3. On the new PC, double-click `PasteBypass.exe` — no install required.
4. If the config file is missing it will be created automatically on first run.

---

## Hotkeys

| Hotkey | Action |
|---|---|
| `Ctrl+Shift+V` | Start typing |
| `Ctrl+Shift+P` | Pause / Resume |
| `Escape` | Emergency stop (while running) |

---

## Modes

### Computer Science Mode
- **CodeHS Brace-Safe** — skips auto-inserted `)`, `]`, `"`, `'` so the editor does not duplicate them
- **No Extra Wrapper** — strips the first method/class signature (when CodeHS already provides it)
- **Paste Body Only** — strips the outermost class/method and types just the body
- **Format Code** — normalises indentation to 4-space tabs before typing

### English / Writing Mode
- **Humanize Text** — rewrites text to sound natural and student-like (requires Claude API key)
- **Polish Grammar** — fixes grammar, spelling, and punctuation (requires Claude API key)
- **Simple / Strong** style options
- **Revert** — restores original text if you do not like the revision

---

## Settings

- **WPM Slider** — 10–300 words per minute, updates live while typing
- **Humanized Typing** — random pauses between words and after punctuation
- **Typing Mistakes** — occasional wrong key → pause → backspace → correct key (Low / Medium / High)

---

## Claude API (English Mode)

Enter your [Anthropic API key](https://console.anthropic.com/) in the key field under English Tools.  
The key is saved to `paste_bypass_config.ini` next to the script/exe.

---

## Troubleshooting

### "Cannot send keystrokes" message
The target window is running as administrator but Paste Bypass is not.  
Fix: right-click `PasteBypass.exe` → **Run as administrator**.  
Only do this if the message keeps appearing — most school sites (CodeHS, Google Docs, etc.) do not need it.

### Config file error on startup
The folder where the exe lives is read-only (common on school PCs with locked `C:\Program Files`).  
Fix: move the `PasteBypass` folder to your Desktop or `Documents` folder.

---

## Why Windows Only?

AutoHotkey v2 uses Windows-specific APIs (`SendInput`, `WinActivate`, `WinHTTP`) that do not exist on other operating systems:

- **Mac** — AutoHotkey does not run on macOS at all. There is no Mac version.
- **Chromebook** — ChromeOS does not run Windows `.exe` files natively. Even with Linux mode enabled, Windows executables are not supported.

To use this tool you need a Windows PC or a Windows virtual machine.
