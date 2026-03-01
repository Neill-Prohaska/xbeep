# Task: Port xbeep Hook Scripts from Bash to PowerShell

## Objective

Write PowerShell (.ps1) equivalents of four bash hook scripts so that xbeep works natively on Windows with Claude Code. Also write `install.ps1` (PowerShell installer) and update `settings.json` hook registration to use PowerShell commands.

The working bash implementation is in this repository under `hooks/scripts/`. Each .ps1 script must produce identical behavior to its .sh counterpart.

## Repository

https://github.com/Neill-Prohaska/xbeep

Clone it and work from the local copy. The bash scripts are the reference implementation — read them before writing anything.

---

## Architecture

xbeep registers three Claude Code hooks via `~/.claude/settings.json`. Each hook is a shell command that receives JSON on stdin and must exit with a specific code.

```
Hook Event            Script                          Exit Code Meaning
─────────────────────────────────────────────────────────────────────────
UserPromptSubmit      user-prompt-submit-beep.ps1     0 = pass through (not /xbeep)
                                                      2 = block prompt (handled /xbeep)
Stop                  stop-beep.ps1                   0 = always
Notification          notification-beep.ps1           0 = always
(none — called by     beep-state.ps1                  0 = enabled, 1 = disabled (check mode)
 other scripts)
```

State is stored in a temp file. Beeping is ON by default (no state file = enabled).

---

## Scripts to Write

### 1. `beep-state.ps1`

**Purpose:** Manage on/off state. Called by other scripts and by the `/xbeep` slash command.

**Interface:**
```
beep-state.ps1 <command>
  enable | on     → write "enabled" to state file, print confirmation
  disable | off   → write "disabled" to state file, print confirmation
  status          → print current state
  toggle | (none) → flip current state
  check           → silent check, exit 0 if enabled, exit 1 if disabled
```

**State file location:** `$env:TEMP\claude_beep_enabled_session`

**Bash reference behavior (read `hooks/scripts/beep-state.sh`):**
- If state file doesn't exist → enabled (return 0)
- If state file contains "disabled" → disabled (return 1)
- Otherwise → enabled (return 0)

### 2. `user-prompt-submit-beep.ps1`

**Purpose:** Intercept `/xbeep` commands from stdin JSON, call beep-state.ps1, block prompt.

**Stdin JSON format:**
```json
{"prompt":"/xbeep off","...":"..."}
```

**Logic:**
1. Read all of stdin
2. If JSON contains `"prompt":"/xbeep` → extract the prompt value, parse the argument after `/xbeep`, call `beep-state.ps1` with that argument, write output to stderr, exit 2
3. Otherwise → exit 0

**PowerShell advantage:** Use `ConvertFrom-Json` instead of the fragile grep/awk extraction the bash version uses:
```powershell
$data = $input_text | ConvertFrom-Json
if ($data.prompt -match '^/xbeep') { ... }
```

### 3. `stop-beep.ps1`

**Purpose:** Play a beep when Claude finishes responding.

**Stdin JSON format:**
```json
{"hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"..."}
```

**Logic:**
1. Read all of stdin FIRST (before any subprocess calls — this ordering matters)
2. Call `beep-state.ps1 check` — if exit code 1, exit 0 silently
3. Loop prevention: extract `stop_hook_active` field value from JSON. If `true`, exit 0. IMPORTANT: do NOT search the entire JSON body for the string "true" — Claude's response text (in `last_assistant_message`) may contain that string. Extract the specific field value only.
4. Play sound, exit 0

### 4. `notification-beep.ps1`

**Purpose:** Play a beep when Claude needs user attention.

**Stdin JSON format:**
```json
{"hook_event_name":"Notification","message":"Claude Code needs your attention","notification_type":"permission_prompt"}
```

**Logic:**
1. Read all of stdin FIRST
2. Call `beep-state.ps1 check` — if exit code 1, exit 0 silently
3. Extract `notification_type` field (for future filtering; currently all types beep)
4. Play sound, exit 0

### 5. `install.ps1`

**Purpose:** Install xbeep on a Windows machine.

**Actions:**
1. Check `$env:USERPROFILE\.claude\` exists (Claude Code installed)
2. Copy `hooks\scripts\*.ps1` to `$env:USERPROFILE\.claude\hooks\xbeep\`
3. Copy `commands\xbeep.md` to `$env:USERPROFILE\.claude\commands\`
4. If `$env:USERPROFILE\.claude\settings.json` doesn't exist, create it with hook registrations
5. If it exists but has no xbeep hooks, print the JSON block for manual merge
6. If it exists and already has xbeep hooks, skip

---

## Sound Playback on Windows

The bash version uses `afplay` (macOS) / `paplay` (Linux) / terminal bell fallback. On Windows, use:

```powershell
# Option A: .NET SoundPlayer (supports .wav files)
$player = New-Object System.Media.SoundPlayer "C:\Windows\Media\Windows Notify System Generic.wav"
$player.Play()  # async

# Option B: System beep (no file needed, always works)
[Console]::Beep(800, 200)  # frequency Hz, duration ms

# Option C: SystemSounds (built-in, no file path needed)
[System.Media.SystemSounds]::Asterisk.Play()
```

**Recommended approach:** Try `SystemSounds::Asterisk.Play()` as default (always available, no file path needed). Allow override via `$env:XBEEP_SOUND` pointing to a .wav file, in which case use `SoundPlayer`. Note: `SoundPlayer` only supports .wav format, not .aiff or .mp3.

---

## Hook Registration for Windows

The `settings.json` hook commands must invoke PowerShell, not bash. The commands should be:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -NoProfile -File \"%USERPROFILE%\\.claude\\hooks\\xbeep\\notification-beep.ps1\"",
            "timeout": 5
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -NoProfile -File \"%USERPROFILE%\\.claude\\hooks\\xbeep\\stop-beep.ps1\"",
            "timeout": 5
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -ExecutionPolicy Bypass -NoProfile -File \"%USERPROFILE%\\.claude\\hooks\\xbeep\\user-prompt-submit-beep.ps1\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**IMPORTANT — unknown and must be tested first:**
- Does Claude Code on Windows execute hook commands via `cmd.exe`, `powershell`, or `pwsh`?
- Does `%USERPROFILE%` expand in the command string, or does the hook runner pass it literally?
- Does `$env:USERPROFILE` work instead? (It would if the runner uses PowerShell, not if it uses cmd.exe)

**First thing to test:** Create a minimal hook that writes to a file to determine what shell Claude Code uses on Windows:
```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "echo %COMSPEC% %PSModulePath% > %TEMP%\\claude_hook_test.txt",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```
Check `%TEMP%\claude_hook_test.txt` after Claude responds. If `%COMSPEC%` expanded, the runner uses cmd.exe. If it's literal `%COMSPEC%`, the runner may use PowerShell or direct exec. This determines the correct command format for hook registration.

---

## PowerShell-Specific Concerns

### Reading stdin
```powershell
# Bash: input=$(cat)
# PowerShell equivalent:
$input_text = [Console]::In.ReadToEnd()
```
Do NOT use `$input` as a variable name — it's an automatic variable in PowerShell and will cause bugs.

### Exit codes
```powershell
# Bash: exit 2
# PowerShell:
exit 2
# This works in .ps1 files invoked via powershell -File
```

### Writing to stderr
```powershell
# Bash: echo "$output" >&2
# PowerShell:
[Console]::Error.WriteLine($output)
```

### Script directory self-reference
```powershell
# Bash: HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# PowerShell:
$HookDir = $PSScriptRoot
$BeepStateScript = Join-Path $HookDir "beep-state.ps1"
```

### Calling another .ps1 and checking exit code
```powershell
# Bash: if ! bash "$BEEP_STATE_SCRIPT" check 2>/dev/null; then exit 0; fi
# PowerShell:
& powershell -NoProfile -File $BeepStateScript "check" 2>$null
if ($LASTEXITCODE -ne 0) { exit 0 }
```

### Debug logging
```powershell
# Controlled by $env:XBEEP_DEBUG
$DebugLog = Join-Path $env:TEMP "claude\stop-hook-debug.log"
function Write-DebugLog($msg) {
    if ($env:XBEEP_DEBUG -eq "1") {
        Add-Content -Path $DebugLog -Value $msg
    }
}
```

### JSON parsing
```powershell
# Bash: grep -o '"notification_type":"[^"]*"' | sed ...
# PowerShell (much cleaner):
$data = $input_text | ConvertFrom-Json
$notifType = $data.notification_type
```

---

## File Naming Convention

Place all .ps1 files alongside the .sh files in `hooks/scripts/`:
```
hooks/scripts/
  beep-state.sh                  ← existing (macOS/Linux)
  beep-state.ps1                 ← new (Windows)
  stop-beep.sh
  stop-beep.ps1
  notification-beep.sh
  notification-beep.ps1
  user-prompt-submit-beep.sh
  user-prompt-submit-beep.ps1
```

`install.ps1` goes at the repository root alongside `install.sh`.

---

## Verification Steps

1. **Hook shell detection test:** Run the minimal hook test above to determine what shell Claude Code uses for hook commands on Windows
2. **beep-state.ps1:** Run `powershell -File beep-state.ps1 on`, `off`, `status`, `toggle`, `check` — verify each produces correct output and exit code
3. **Sound test:** Run `[System.Media.SystemSounds]::Asterisk.Play()` in PowerShell to confirm audio works
4. **user-prompt-submit-beep.ps1:** Pipe test JSON and verify exit codes:
   ```powershell
   '{"prompt":"/xbeep off"}' | powershell -File user-prompt-submit-beep.ps1
   # Should print "Beep notifications disabled" to stderr, exit 2
   '{"prompt":"hello"}' | powershell -File user-prompt-submit-beep.ps1
   # Should exit 0 silently
   ```
5. **stop-beep.ps1:** Pipe test JSON and verify beep plays:
   ```powershell
   '{"hook_event_name":"Stop","stop_hook_active":false}' | powershell -File stop-beep.ps1
   # Should play sound
   ```
6. **Loop prevention:** Verify that `stop_hook_active` check uses field extraction, not string search:
   ```powershell
   '{"hook_event_name":"Stop","stop_hook_active":false,"last_assistant_message":"stop_hook_active is true in the code"}' | powershell -File stop-beep.ps1
   # Should still play sound (stop_hook_active field is false)
   ```
7. **End-to-end:** Install via `install.ps1`, start new Claude Code session, verify beeps fire on stop and notification events, verify `/xbeep off` and `/xbeep on` work
