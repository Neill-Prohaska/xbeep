#!/bin/bash

# Notification Beep Hook for Claude Code
# Beeps when Claude requests permission or needs user attention

# --- Configuration ---
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
BEEP_STATE_SCRIPT="${HOOK_DIR}/beep-state.sh"
XBEEP_DEBUG="${XBEEP_DEBUG:-0}"
DEBUG_LOG="/tmp/claude/notification-hook-debug.log"

# WSL detection
is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

# Sound: XBEEP_SOUND env var > OS-appropriate default > terminal bell fallback
if [ -n "${XBEEP_SOUND:-}" ]; then
    SOUND_FILE="$XBEEP_SOUND"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    SOUND_FILE="/System/Library/Sounds/Glass.aiff"
elif [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]] || is_wsl; then
    SOUND_FILE="${HOOK_DIR}/universfield-ping.wav"
else
    SOUND_FILE=""  # Linux: play_sound() will use terminal bell
fi

# --- Debug logging (only when XBEEP_DEBUG=1) ---
log_debug() {
    if [[ "$XBEEP_DEBUG" == "1" ]]; then
        echo "$@" >> "$DEBUG_LOG"
    fi
}

if [[ "$XBEEP_DEBUG" == "1" ]]; then
    mkdir -p -m 700 "$(dirname "$DEBUG_LOG")"
    log_debug "=== $(date '+%Y-%m-%d %H:%M:%S') notification-hook ==="
fi

# --- Cross-platform sound playback ---
play_sound() {
    local sound_file="$1"
    if [ -f "$sound_file" ] && command -v afplay &>/dev/null; then
        afplay "$sound_file" &          # macOS
    elif is_wsl && [ -f "$sound_file" ] && command -v powershell.exe &>/dev/null; then
        local win_path
        win_path=$(wslpath -w "$sound_file" 2>/dev/null)
        powershell.exe -NoProfile -NonInteractive -c "(New-Object Media.SoundPlayer '$win_path').PlaySync()" &>/dev/null &  # WSL
    elif [ -f "$sound_file" ] && command -v paplay &>/dev/null; then
        paplay "$sound_file" &          # Linux (PulseAudio)
    elif [ -f "$sound_file" ] && command -v aplay &>/dev/null; then
        aplay -q "$sound_file" &        # Linux (ALSA)
    elif [ -f "$sound_file" ] && command -v powershell.exe &>/dev/null; then
        # Windows (Git Bash/MSYS/Cygwin): PowerShell MediaPlayer supports WAV/MP3
        local win_path
        win_path=$(cygpath -w "$sound_file" 2>/dev/null || echo "$sound_file")
        powershell.exe -NoProfile -Command \
            "Add-Type -AssemblyName PresentationCore; \$p = [System.Windows.Media.MediaPlayer]::new(); \$p.Open([uri]'${win_path}'); \$p.Play(); Start-Sleep -Seconds 3" &>/dev/null &
    else
        printf '\a'                     # Terminal bell fallback
    fi
}

# --- Read stdin FIRST (before any subprocess calls) ---
input=$(cat)
log_debug "Input (first 300 chars): ${input:0:300}"

# --- Check if beeping is enabled ---
if ! bash "$BEEP_STATE_SCRIPT" check 2>/dev/null; then
    log_debug "Beeping DISABLED, exiting"
    exit 0
fi
log_debug "Beeping ENABLED"

# --- Determine notification type from structured field ---
# The JSON payload includes a notification_type field (e.g., "permission_prompt").
# Use proper field extraction instead of grepping the whole message body.
notif_type=$(echo "$input" | grep -o '"notification_type":"[^"]*"' | sed 's/"notification_type":"//;s/"//')
log_debug "Notification type: '${notif_type:-<empty>}'"

SHOULD_BEEP=true
case "$notif_type" in
    permission_prompt) SHOULD_BEEP=true ;;
    "")                SHOULD_BEEP=true ;;  # Unknown/missing type, beep to be safe
    *)                 SHOULD_BEEP=true ;;  # Default to beep; add exclusions as needed
esac

# --- Play the beep ---
if [ "$SHOULD_BEEP" = true ]; then
    log_debug "Playing beep sound (type: ${notif_type:-unknown})"
    play_sound "$SOUND_FILE"
    log_debug "Notification hook completed (sound PID: $!)"
else
    log_debug "Skipping beep for type: $notif_type"
fi

exit 0
