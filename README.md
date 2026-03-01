# xbeep — Audible Notifications for Claude Code

Plays a beep sound when Claude Code finishes responding or needs your input (e.g., permission prompts). Useful when you tab away during long-running tasks.

## Features

- Beeps when Claude finishes a response (so you know it's your turn)
- Beeps when Claude needs permission to proceed (e.g., to run a command)
- Toggle beeps on/off any time by typing `/xbeep` in Claude Code
- Works on macOS, Linux, and Windows

## What you need

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) already installed and working (you should have a `~/.claude/` directory)
- macOS or Linux (bash required), or Windows (PowerShell)

## Installation

### Step 1: Download this repository

```bash
git clone https://github.com/Neill-Prohaska/xbeep.git
```

This creates a folder called `xbeep` on your machine.

(Alternatively, on GitHub click the green **Code** button, then **Download ZIP**. Unzip it — you'll get a folder called `xbeep-main`.)

### Step 2: Run the installer

```bash
cd xbeep
bash install.sh
```

If you downloaded the ZIP instead:

```bash
cd xbeep-main
bash install.sh
```

The installer copies the necessary files into your Claude Code configuration directory (`~/.claude/`) and registers the notification hooks. You'll see a summary of what it did when it finishes.

### Windows installation

```powershell
git clone https://github.com/Neill-Prohaska/xbeep.git
cd xbeep
powershell -ExecutionPolicy Bypass -File install.ps1
```

To uninstall:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

### Step 3: Restart Claude Code

Close and reopen Claude Code. The beep notifications are now active.

### What if the installer says "merge manually"?

If you already have custom settings in `~/.claude/settings.json`, the installer can't safely modify it automatically. It will print a block of text and ask you to add it to your settings file. Open `~/.claude/settings.json` in a text editor and paste the printed block inside the outer `{ }` braces. If your file already has a `"hooks"` section, add the three new entries (Notification, Stop, UserPromptSubmit) inside the existing `"hooks"` block rather than creating a duplicate.

If this is confusing, ask Claude Code for help: *"Please merge xbeep hooks into my ~/.claude/settings.json"*

## Uninstall

From the folder where you originally ran the installer:

```bash
bash install.sh --uninstall
```

This removes the scripts and the `/xbeep` command. You'll also need to manually remove the hook entries from `~/.claude/settings.json` (the uninstaller will remind you which ones).

## Usage

Once installed, beeps are on by default. In any Claude Code session, you can control them by typing:

| Command          | Action                        |
|------------------|-------------------------------|
| `/xbeep`         | Toggle beep on/off            |
| `/xbeep on`      | Enable beeps                  |
| `/xbeep off`     | Disable beeps                 |
| `/xbeep status`  | Show current state            |

This setting lasts for the current terminal session only. When you open a new terminal, beeps start enabled again.

## Configuration (optional)

### Custom sound

By default, xbeep plays the macOS system sound "Glass". On Linux, it uses the terminal bell. On Windows, it plays a bundled notification sound (`universfield-ping.wav`).

To use a different sound, set the `XBEEP_SOUND` environment variable to a sound file path.

**macOS / Linux** — add to your shell profile (e.g., `~/.zshrc` or `~/.bashrc`):

```bash
export XBEEP_SOUND="/path/to/your/sound.wav"
```

Some macOS sounds you can try (all in `/System/Library/Sounds/`): `Glass.aiff`, `Ping.aiff`, `Pop.aiff`, `Tink.aiff`, `Purr.aiff`

**Windows** — the sound file must be a `.wav` file. To set it for the current session:

```powershell
$env:XBEEP_SOUND = 'C:\path\to\sound.wav'
```

To make it persistent across all sessions, set it as a user environment variable:

```powershell
[Environment]::SetEnvironmentVariable('XBEEP_SOUND', 'C:\path\to\sound.wav', 'User')
```

Then restart Claude Code. Some Windows sounds you can try (in `C:\Windows\Media\`): `Windows Notify System Generic.wav`, `Windows Notify Calendar.wav`, `chimes.wav`, `notify.wav`

### Debug mode

If beeps aren't working and you want to see what's happening:

```bash
export XBEEP_DEBUG=1
```

Then restart Claude Code. Logs will appear in `/tmp/claude/` (macOS/Linux) or `%TEMP%\claude\` (Windows):
- `hook-debug.log` — command interception log
- `stop-hook-debug.log` — response-complete beep log
- `notification-hook-debug.log` — permission-prompt beep log

On Windows, set the debug variable with:

```powershell
$env:XBEEP_DEBUG = '1'
```

## How it works (technical)

You don't need to understand this to use xbeep. This section is for anyone who wants to know what the installer put on their system.

Claude Code supports "hooks" — shell commands that run automatically when certain events happen. xbeep registers three hooks:

1. When Claude finishes responding ("Stop" event), a script plays a beep sound.
2. When Claude needs your attention, like asking permission to run a command ("Notification" event), a script plays a beep sound.
3. When you type `/xbeep` ("UserPromptSubmit" event), a script intercepts the command, toggles the beep state, and prevents the text from being sent to Claude as a question.

The installer places the hook scripts in `~/.claude/hooks/xbeep/` and the `/xbeep` slash command in `~/.claude/commands/`. The hooks are registered in `~/.claude/settings.json`.

Beep on/off state is stored in a temporary file that is automatically cleaned up when your computer restarts.

**Note:** On macOS Terminal.app and on Windows, each Claude Code session has its own beep state. On other terminals (iTerm2, Linux terminals, WSL), all Claude Code sessions share the same beep state.

## License

MIT
