# xbeep — Audible Notifications for Claude Code

Plays a beep sound when Claude Code finishes responding or needs your input
(e.g., permission prompts). Useful when you tab away during long-running tasks.

## Features

- Beeps on **Stop** events (Claude finished responding)
- Beeps on **Notification** events (permission prompts, user attention needed)
- Session-scoped toggle via `/xbeep` slash command
- Cross-platform: macOS (afplay), Linux (PulseAudio/ALSA), terminal bell fallback
- Customizable sound via `XBEEP_SOUND` environment variable
- Debug mode via `XBEEP_DEBUG=1`

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
  (the `~/.claude/` directory must exist)
- macOS or Linux
- **Windows:** Not supported natively. These are bash scripts and require a
  Unix shell. If you run Claude Code from within WSL, xbeep will work.

## Installation

### Quick install

1. Copy or download the `xbeep/` folder to anywhere on your machine.

2. Run the installer:

   ```bash
   cd xbeep
   bash install.sh
   ```

   The installer will:
   - Copy hook scripts to `~/.claude/hooks/xbeep/`
   - Copy the `/xbeep` slash command to `~/.claude/commands/`
   - Register hooks in `~/.claude/settings.json`

3. **Start a new Claude Code session** for the hooks to take effect.

### What if I already have a settings.json?

If `~/.claude/settings.json` already exists with other settings, the installer
will print the hooks block and ask you to merge it manually. Add the three hook
entries (Notification, Stop, UserPromptSubmit) into your existing `"hooks"` key.

### Manual installation (no installer)

If you prefer not to use the installer:

1. Copy `hooks/scripts/*.sh` to `~/.claude/hooks/xbeep/`
2. Copy `commands/xbeep.md` to `~/.claude/commands/`
3. Add the following to `~/.claude/settings.json` (merge into existing file
   if one exists):

   ```json
   {
     "hooks": {
       "Notification": [
         {
           "matcher": "",
           "hooks": [
             {
               "type": "command",
               "command": "bash \"$HOME/.claude/hooks/xbeep/notification-beep.sh\"",
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
               "command": "bash \"$HOME/.claude/hooks/xbeep/stop-beep.sh\"",
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
               "command": "bash \"$HOME/.claude/hooks/xbeep/user-prompt-submit-beep.sh\"",
               "timeout": 5
             }
           ]
         }
       ]
     }
   }
   ```

4. Start a new Claude Code session.

## Uninstall

```bash
cd xbeep
bash install.sh --uninstall
```

This removes the scripts and slash command. You'll need to manually remove
the hook entries from `~/.claude/settings.json`.

## Usage

In any Claude Code session:

| Command          | Action                        |
|------------------|-------------------------------|
| `/xbeep`         | Toggle beep on/off            |
| `/xbeep on`      | Enable beeps                  |
| `/xbeep off`     | Disable beeps                 |
| `/xbeep status`  | Show current state            |

Beeping is **enabled by default** when you start a new session.

## Configuration

### Custom sound

Set the `XBEEP_SOUND` environment variable (in your shell profile) to use
a different sound file:

```bash
export XBEEP_SOUND="/path/to/your/sound.wav"
```

On macOS, the default is `/System/Library/Sounds/Glass.aiff`. Other macOS
sounds are in the same directory (e.g., `Ping.aiff`, `Pop.aiff`, `Tink.aiff`).

On Linux, if no sound file is found or no compatible player (paplay, aplay)
is available, it falls back to the terminal bell (`\a`).

### Debug mode

Enable verbose logging to diagnose issues:

```bash
export XBEEP_DEBUG=1
```

Logs are written to `/tmp/claude/` with restricted permissions (mode `700`).
Three log files are created:
- `hook-debug.log` — UserPromptSubmit hook (slash command interception)
- `stop-hook-debug.log` — Stop hook (response-complete beeps)
- `notification-hook-debug.log` — Notification hook (permission beeps)

## How it works

xbeep uses Claude Code's [hooks system](https://docs.anthropic.com/en/docs/claude-code/hooks)
to intercept three lifecycle events:

- **UserPromptSubmit** — intercepts `/xbeep` commands, toggles beep state,
  and exits with code 2 to block the prompt from reaching Claude
- **Stop** — plays a sound when Claude finishes its response
- **Notification** — plays a sound when Claude needs user attention
  (e.g., permission prompts)

Beep state is stored in a temp file scoped to your terminal session
(`$TMPDIR/claude_beep_enabled_<session_id>`). On macOS Terminal.app,
each window gets independent on/off state via `TERM_SESSION_ID`. On
other terminals (iTerm2, Linux terminals, WSL), all sessions in the
same user account share beep state.

## File layout

```
xbeep/
  .claude-plugin/
    plugin.json                    # Plugin manifest
  commands/
    xbeep.md                       # /xbeep slash command definition
  hooks/scripts/
    beep-state.sh                  # State management (on/off/toggle/status)
    user-prompt-submit-beep.sh     # Intercepts /xbeep commands
    stop-beep.sh                   # Beeps on Stop events
    notification-beep.sh           # Beeps on Notification events
  install.sh                       # Installer (also supports --uninstall)
  readme.txt                       # Plain-text documentation
  README.md                        # This file (Markdown)
```

## License

MIT
