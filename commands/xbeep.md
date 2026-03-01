---
description: Toggle audible beep notifications for this Claude Code session
tags: [notifications, beep, hooks, session]
argument-hint: [on|off|status|toggle]
---

# Beep State Management

Control audible beep notifications for this session.

**Available options:**
- `on` or `enable` - Enable beeping
- `off` or `disable` - Disable beeping
- `status` - Show current state
- No argument - Toggle current state

**Executing beep state script:**

On Windows, execute:
```powershell
powershell -ExecutionPolicy Bypass -NoProfile -File "$env:USERPROFILE\.claude\hooks\xbeep\beep-state.ps1" $ARGUMENTS
```

On macOS/Linux, execute:
```bash
bash "$HOME/.claude/hooks/xbeep/beep-state.sh" $ARGUMENTS
```

Based on the output, briefly confirm the beep notification state change.
