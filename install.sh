#!/bin/bash

# xbeep installer for Claude Code
# Installs audible notification beeps without the plugin system
#
# Usage: bash install.sh [--uninstall]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_DEST="$HOME/.claude/hooks/xbeep"
CMD_DEST="$HOME/.claude/commands"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Colors (if terminal supports them)
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' NC=''
fi

info()  { echo -e "${GREEN}[xbeep]${NC} $*"; }
warn()  { echo -e "${YELLOW}[xbeep]${NC} $*"; }
error() { echo -e "${RED}[xbeep]${NC} $*" >&2; }

# --- Uninstall ---
if [[ "${1:-}" == "--uninstall" ]]; then
    info "Uninstalling xbeep..."

    if [ -d "$HOOK_DEST" ]; then
        rm -rf "$HOOK_DEST"
        info "Removed $HOOK_DEST"
    fi

    if [ -f "$CMD_DEST/xbeep.md" ]; then
        rm "$CMD_DEST/xbeep.md"
        info "Removed $CMD_DEST/xbeep.md"
    fi

    warn "Hook registrations in $SETTINGS_FILE must be removed manually."
    warn "Remove the Notification, Stop, and UserPromptSubmit entries that reference xbeep."
    info "Uninstall complete."
    exit 0
fi

# --- Install ---
info "Installing xbeep for Claude Code..."

# Check prerequisites
if [ ! -d "$HOME/.claude" ]; then
    error "~/.claude directory not found. Is Claude Code installed?"
    exit 1
fi

# Copy hook scripts
info "Installing hook scripts to $HOOK_DEST/"
mkdir -p "$HOOK_DEST"
cp "$SCRIPT_DIR/hooks/scripts/"*.sh "$HOOK_DEST/"
chmod +x "$HOOK_DEST/"*.sh

# Copy default Windows notification sound (needed on Windows for MP3 playback)
if [[ "$OSTYPE" == msys* || "$OSTYPE" == cygwin* ]]; then
    info "Copying default Windows notification sound..."
    cp "$SCRIPT_DIR/universfield-happy-message-ping-351298.mp3" "$HOOK_DEST/"
fi

# Copy slash command
info "Installing /xbeep command to $CMD_DEST/"
mkdir -p "$CMD_DEST"
cp "$SCRIPT_DIR/commands/xbeep.md" "$CMD_DEST/"

# Register hooks in global settings
info "Registering hooks in $SETTINGS_FILE..."

if [ ! -f "$SETTINGS_FILE" ]; then
    # Create minimal settings with hooks
    cat > "$SETTINGS_FILE" << 'SETTINGS'
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
SETTINGS
    info "Created $SETTINGS_FILE with hook registrations."
else
    # Settings file exists — check if hooks are already registered
    if grep -q "xbeep" "$SETTINGS_FILE" 2>/dev/null; then
        info "Hook registrations already present in $SETTINGS_FILE — skipping."
    else
        warn "Existing $SETTINGS_FILE found but no xbeep hooks detected."
        warn "Please add the following hooks block to your settings manually:"
        echo ""
        cat << 'HOOKS_BLOCK'
  "hooks": {
    "Notification": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/hooks/xbeep/notification-beep.sh\"", "timeout": 5 }] }
    ],
    "Stop": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/hooks/xbeep/stop-beep.sh\"", "timeout": 5 }] }
    ],
    "UserPromptSubmit": [
      { "matcher": "", "hooks": [{ "type": "command", "command": "bash \"$HOME/.claude/hooks/xbeep/user-prompt-submit-beep.sh\"", "timeout": 5 }] }
    ]
  }
HOOKS_BLOCK
        echo ""
        warn "Merge this into the existing \"hooks\" key in $SETTINGS_FILE"
    fi
fi

# Verify installation
echo ""
info "Installation complete!"
echo ""
echo "  Scripts: $HOOK_DEST/"
echo "  Command: $CMD_DEST/xbeep.md"
echo "  Settings: $SETTINGS_FILE"
echo ""
echo "  Usage (in Claude Code):"
echo "    /xbeep          Toggle beep on/off"
echo "    /xbeep on       Enable beeps"
echo "    /xbeep off      Disable beeps"
echo "    /xbeep status   Show current state"
echo ""
echo "  Configuration:"
echo "    XBEEP_SOUND=/path/to/sound.wav   Custom sound file"
echo "    XBEEP_DEBUG=1                    Enable debug logging"
echo ""
info "Start a new Claude Code session for hooks to take effect."
