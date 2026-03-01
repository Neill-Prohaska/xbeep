# xbeep Troubleshooting Guide

This document is for Claude Code to use when diagnosing xbeep issues. When a user reports an xbeep problem, read this file first, then follow the diagnostic tree.

---

## Diagnostic Approach

Do NOT guess at causes. Run the diagnostic commands for the reported symptom and use the output to determine the actual problem. Change one thing at a time and verify before proceeding.

---

## Symptom → Diagnostic Tree

### "Operation blocked by hook"

This means a UserPromptSubmit hook returned exit code 2. In xbeep, exit 2 is intentional — it means the hook intercepted a `/xbeep` command and handled it. This message is EXPECTED when the user types `/xbeep`.

**If it happens on EVERY prompt (not just /xbeep), the hook script is broken.**

Diagnostic steps:

```bash
# 1. Find the hook command registered in settings
cat ~/.claude/settings.json | grep -A3 "UserPromptSubmit" | grep "command"

# 2. Test the script directly with a non-/xbeep input
echo '{"prompt":"hello world"}' | bash ~/.claude/hooks/xbeep/user-prompt-submit-beep.sh
echo "Exit code: $?"
# Expected: exit code 0 (pass through)

# 3. Test with a /xbeep input
echo '{"prompt":"/xbeep status"}' | bash ~/.claude/hooks/xbeep/user-prompt-submit-beep.sh
echo "Exit code: $?"
# Expected: exit code 2 (blocked), status message on stderr
```

**Common causes of blocking all prompts:**
- Script crashes before reaching the grep check → shell returns non-zero, which Claude Code may interpret as blocking. Check: does `bash` exist at the path? Does the script have syntax errors? Run `bash -n ~/.claude/hooks/xbeep/user-prompt-submit-beep.sh` to syntax-check without executing.
- On Windows: the hook command says `bash "..."` but bash is not installed → the command fails, and the failure exit code may be 2 or may be interpreted as blocking. Check: run `where bash` (cmd) or `Get-Command bash` (PowerShell). If bash is not found, xbeep bash scripts cannot work — see `xbeep_for_windows.md` for the PowerShell port.
- Script path is wrong → file not found error → non-zero exit. Check: does the file at the path in settings.json actually exist?
- `$HOME` is not expanding → bash receives literal `$HOME/.claude/...` as the path → file not found. Check: run the exact command string from settings.json in a terminal and see if it works.

### No beep when Claude finishes responding

The Stop hook is not firing or not producing sound.

```bash
# 1. Is xbeep enabled?
bash ~/.claude/hooks/xbeep/beep-state.sh status

# 2. Does the stop hook script exist at the registered path?
cat ~/.claude/settings.json | grep -A3 "Stop" | grep "command"
# Then check that file exists:
ls -la ~/.claude/hooks/xbeep/stop-beep.sh

# 3. Test the stop hook directly
echo '{"hook_event_name":"Stop","stop_hook_active":false}' | bash ~/.claude/hooks/xbeep/stop-beep.sh
# Expected: you hear a beep sound

# 4. If no sound, test sound playback directly
# macOS:
afplay /System/Library/Sounds/Glass.aiff
# Linux:
paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || aplay /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null || printf '\a'

# 5. Enable debug logging and try again
export XBEEP_DEBUG=1
echo '{"hook_event_name":"Stop","stop_hook_active":false}' | bash ~/.claude/hooks/xbeep/stop-beep.sh
cat /tmp/claude/stop-hook-debug.log
```

**Common causes:**
- Hook not registered in settings.json → check settings file has a "Stop" hook entry pointing to xbeep
- Beep state is disabled → run `bash ~/.claude/hooks/xbeep/beep-state.sh on`
- Sound file doesn't exist and no fallback player available → debug log will show this
- On macOS: `afplay` command not found (unlikely but possible in restricted environments)
- On Linux: no `paplay` or `aplay` installed → only terminal bell works, which may be silent depending on terminal settings
- The hook is registered but in a project settings.local.json that doesn't apply to the current directory
- Claude Code session was not restarted after installation → hooks only load at session start

### No beep on permission prompts

The Notification hook is not firing.

```bash
# 1. Is xbeep enabled?
bash ~/.claude/hooks/xbeep/beep-state.sh status

# 2. Test notification hook directly
echo '{"hook_event_name":"Notification","message":"test","notification_type":"permission_prompt"}' | bash ~/.claude/hooks/xbeep/notification-beep.sh
# Expected: you hear a beep sound

# 3. Check hook registration
cat ~/.claude/settings.json | grep -A3 "Notification" | grep "command"
```

Same causes as "No beep when Claude finishes" above.

### /xbeep command not recognized (Claude responds to it as a question)

The `/xbeep` slash command file is missing or the UserPromptSubmit hook is not registered.

```bash
# 1. Does the slash command file exist?
ls -la ~/.claude/commands/xbeep.md

# 2. Is the UserPromptSubmit hook registered?
cat ~/.claude/settings.json | grep -A5 "UserPromptSubmit"

# 3. If the command file exists but Claude still responds:
# The hook may not be intercepting it. Test directly:
echo '{"prompt":"/xbeep"}' | bash ~/.claude/hooks/xbeep/user-prompt-submit-beep.sh
echo "Exit code: $?"
# Expected: exit code 2
```

**Common causes:**
- `~/.claude/commands/xbeep.md` doesn't exist → reinstall: copy from repo `commands/xbeep.md`
- UserPromptSubmit hook not in settings.json → add it
- Hook command path is wrong → script not found → exit 0 (pass through to Claude)

### Beep plays but /xbeep on/off/status doesn't work

The slash command runs but the argument isn't being passed correctly.

```bash
# 1. Test argument extraction directly
echo '{"prompt":"/xbeep off"}' | bash ~/.claude/hooks/xbeep/user-prompt-submit-beep.sh
# Expected: stderr shows "Beep notifications disabled"

echo '{"prompt":"/xbeep status"}' | bash ~/.claude/hooks/xbeep/user-prompt-submit-beep.sh
# Expected: stderr shows current state

# 2. Enable debug logging
export XBEEP_DEBUG=1
echo '{"prompt":"/xbeep off"}' | bash ~/.claude/hooks/xbeep/user-prompt-submit-beep.sh
cat /tmp/claude/hook-debug.log
# Check "Extracted prompt" and "Argument" lines
```

### Beep randomly doesn't fire (intermittent)

```bash
# 1. Check if it correlates with Claude discussing xbeep code
# Known bug in pre-v2.0.0: if Claude's response contained the strings
# "stop_hook_active" and "true", the stop hook's loop prevention
# mistakenly matched and suppressed the beep. This is fixed in v2.0.0.
# Check version: does stop-beep.sh use grep -qi on the full input,
# or does it extract the specific field?
grep -n "stop_hook_active" ~/.claude/hooks/xbeep/stop-beep.sh
# Fixed version (v2.0.0) has:
#   stop_active=$(echo "$input" | grep -o '"stop_hook_active":[a-z]*' | head -1 | sed 's/.*://')
# Buggy version has:
#   echo "$input" | grep -qi '"stop_hook_active".*true'

# 2. Check if beep state file is being shared across sessions
echo "State file location:"
bash ~/.claude/hooks/xbeep/beep-state.sh status
# If another terminal session ran /xbeep off, this session is also off.
# This is expected on non-Terminal.app terminals (iTerm2, Linux, WSL)
# where TERM_SESSION_ID is not set.

# 3. Enable debug logging across hooks
export XBEEP_DEBUG=1
# Then reproduce the issue and check all three log files:
cat /tmp/claude/stop-hook-debug.log
cat /tmp/claude/notification-hook-debug.log
cat /tmp/claude/hook-debug.log
```

---

## Settings File Issues

### settings.json is malformed after manual merge

```bash
# Validate JSON syntax
python3 -c "import json; json.load(open('$HOME/.claude/settings.json'))" 2>&1
# Or if python3 unavailable:
node -e "JSON.parse(require('fs').readFileSync('$HOME/.claude/settings.json','utf8'))"
```

Common JSON errors after manual merge:
- Missing comma between the last existing key and the new `"hooks"` key
- Duplicate `"hooks"` key (existing hooks + pasted xbeep hooks) → only one takes effect
- Trailing comma after the last entry in an array or object

### Hooks in wrong settings file

Claude Code has multiple settings scopes that merge:
- `~/.claude/settings.json` — global (recommended for xbeep)
- `<project>/.claude/settings.json` — project, checked into git
- `<project>/.claude/settings.local.json` — project-local, not in git

xbeep hooks should be in the global file (`~/.claude/settings.json`) so they work in all projects. If they're in a project settings file, they only work in that project directory.

```bash
# Check all settings files for xbeep hooks
grep -l "xbeep" ~/.claude/settings.json .claude/settings.json .claude/settings.local.json 2>/dev/null
```

---

## Platform-Specific Issues

### macOS
- Sound file `/System/Library/Sounds/Glass.aiff` should always exist
- `afplay` is a system utility, always available
- `TERM_SESSION_ID` is set by Terminal.app only, not iTerm2

### Linux
- Default sound file path (`/System/Library/Sounds/Glass.aiff`) does not exist → falls back to terminal bell
- Terminal bell (`printf '\a'`) may be silent if the terminal has bell disabled
- Check: `xdotool getactivewindow` or test with `printf '\a'` directly
- For audible beeps, set `XBEEP_SOUND` to a .wav or .ogg file and ensure `paplay` or `aplay` is installed
- `TERM_SESSION_ID` is not set → all sessions share beep state

### Windows (native — not WSL)
- Bash scripts do NOT work on native Windows
- If hooks are registered with `bash "..."` commands and bash is not on PATH, every hook invocation fails
- See `xbeep_for_windows.md` for the PowerShell port
- Error symptoms: "Operation blocked by hook" on all prompts, or hooks silently failing

### Windows (WSL)
- Bash scripts work inside WSL
- `afplay` does not exist → falls back to terminal bell or `paplay`/`aplay`
- Sound may not work if WSL doesn't have PulseAudio configured
- `$TMPDIR` may not be set → falls back to `/tmp`

---

## Quick Reset

If xbeep is in a bad state and you want to start clean:

```bash
# 1. Re-enable beeps (in case state file says disabled)
bash ~/.claude/hooks/xbeep/beep-state.sh on

# 2. Or delete the state file entirely (resets to default = enabled)
rm -f ${TMPDIR:-/tmp}/claude_beep_enabled_*

# 3. Verify hooks are registered
cat ~/.claude/settings.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
hooks = d.get('hooks', {})
for event in ['Notification', 'Stop', 'UserPromptSubmit']:
    if event in hooks:
        print(f'{event}: registered')
    else:
        print(f'{event}: MISSING')
"

# 4. Restart Claude Code (hooks load at session start only)
```

---

## Enabling Debug Mode

Set this environment variable BEFORE starting Claude Code:

```bash
export XBEEP_DEBUG=1
```

Then reproduce the issue. Three log files are created in `/tmp/claude/`:

| Log file | Hook | What it records |
|----------|------|-----------------|
| `hook-debug.log` | UserPromptSubmit | Every prompt, /xbeep extraction, beep-state.sh output |
| `stop-hook-debug.log` | Stop | Every stop event, beep state check, loop prevention, sound playback |
| `notification-hook-debug.log` | Notification | Every notification, type extraction, sound playback |

Read the relevant log file. The timestamps and decision points will show exactly where the flow diverged from expected behavior.

To disable debug logging afterward:

```bash
unset XBEEP_DEBUG
```
