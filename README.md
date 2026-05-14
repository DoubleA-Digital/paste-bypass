# Paste Bypass — Auto Typer

An AutoHotkey v2 script that types clipboard or preview-box text character-by-character with human-like behaviour.  
Built for bypassing paste-disabled fields (e.g. CodeHS, online exams) and essay submission sites.

## Requirements
- [AutoHotkey v2](https://www.autohotkey.com/) (free download)

## Quick Start
1. Install AutoHotkey v2
2. Double-click `paste_bypass.ahk` to launch the GUI
3. Copy text → click **Refresh** → click **Start**

## Hotkeys
| Hotkey | Action |
|---|---|
| `Ctrl+Shift+V` | Start typing |
| `Ctrl+Shift+P` | Pause / Resume |
| `Escape` | Emergency stop (while running) |

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

## Settings
- **WPM Slider** — 10–300 words per minute, updates live while typing
- **Humanized Typing** — random pauses between words and after punctuation
- **Typing Mistakes** — occasional wrong key → pause → backspace → correct key (Low / Medium / High)

## Claude API (English Mode)
Enter your [Anthropic API key](https://console.anthropic.com/) in the key field under English Tools.  
The key is saved to `paste_bypass_config.ini` next to the script.
