# xbeep installer for Claude Code (Windows)
# Installs audible notification beeps
#
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1 [-Uninstall]

param(
    [switch]$Uninstall
)

$ScriptDir = $PSScriptRoot
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$HookDest = Join-Path $ClaudeDir "hooks\xbeep"
$CmdDest = Join-Path $ClaudeDir "commands"
$SettingsFile = Join-Path $ClaudeDir "settings.json"

function Write-Info($msg)  { Write-Host "[xbeep] $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "[xbeep] $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[xbeep] $msg" -ForegroundColor Red }

# Write JSON without UTF-8 BOM (Windows PowerShell 5.1's -Encoding UTF8 adds BOM)
function Write-JsonNoBom {
    param([string]$Path, [string]$Json)
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Json, $utf8NoBom)
}

# Remove xbeep hook entries from a settings object, returns modified object
function Remove-XbeepHooks {
    param($Settings)
    if (-not $Settings.hooks) { return $Settings }
    foreach ($hookType in @("Notification", "Stop", "UserPromptSubmit")) {
        if ($Settings.hooks.$hookType) {
            $filtered = @($Settings.hooks.$hookType | Where-Object {
                $dominated = $false
                foreach ($h in $_.hooks) {
                    if ($h.command -match "xbeep") { $dominated = $true }
                }
                -not $dominated
            })
            if ($filtered.Count -eq 0) {
                $Settings.hooks.PSObject.Properties.Remove($hookType)
            } else {
                $Settings.hooks.$hookType = $filtered
            }
        }
    }
    # Remove hooks key entirely if empty
    if (@($Settings.hooks.PSObject.Properties).Count -eq 0) {
        $Settings.PSObject.Properties.Remove("hooks")
    }
    return $Settings
}

# --- Uninstall ---
if ($Uninstall) {
    Write-Info "Uninstalling xbeep..."

    if (Test-Path $HookDest) {
        Remove-Item $HookDest -Recurse -Force
        Write-Info "Removed $HookDest"
    }

    $cmdFile = Join-Path $CmdDest "xbeep.md"
    if (Test-Path $cmdFile) {
        Remove-Item $cmdFile -Force
        Write-Info "Removed $cmdFile"
    }

    # Clean up settings.json hook registrations
    if (Test-Path $SettingsFile) {
        try {
            $content = Get-Content $SettingsFile -Raw
            if ($content -match "xbeep") {
                $settings = $content | ConvertFrom-Json
                $settings = Remove-XbeepHooks $settings
                $json = $settings | ConvertTo-Json -Depth 10
                Write-JsonNoBom $SettingsFile $json
                Write-Info "Removed xbeep hook registrations from $SettingsFile"
            } else {
                Write-Info "No xbeep hooks found in $SettingsFile"
            }
        } catch {
            Write-Warn "Could not auto-clean $SettingsFile: $_"
            Write-Warn "Remove the Notification, Stop, and UserPromptSubmit entries that reference xbeep manually."
        }
    }

    Write-Info "Uninstall complete."
    exit 0
}

# --- Install ---
Write-Info "Installing xbeep for Claude Code (Windows)..."

# Check prerequisites
if (-not (Test-Path $ClaudeDir)) {
    Write-Err "$ClaudeDir not found. Is Claude Code installed?"
    exit 1
}

# Copy hook scripts (.ps1 files)
Write-Info "Installing hook scripts to $HookDest\"
if (-not (Test-Path $HookDest)) {
    New-Item -ItemType Directory -Path $HookDest -Force | Out-Null
}
Copy-Item (Join-Path $ScriptDir "hooks\scripts\*.ps1") -Destination $HookDest -Force
# Copy bundled notification sound
$wavFile = Join-Path $ScriptDir "universfield-ping.wav"
if (Test-Path $wavFile) {
    Copy-Item $wavFile -Destination $HookDest -Force
}
Write-Info "Copied PowerShell scripts and notification sound."

# Copy slash command
Write-Info "Installing /xbeep command to $CmdDest\"
if (-not (Test-Path $CmdDest)) {
    New-Item -ItemType Directory -Path $CmdDest -Force | Out-Null
}
Copy-Item (Join-Path $ScriptDir "commands\xbeep.md") -Destination $CmdDest -Force

# Build the hooks JSON block using the resolved absolute path
# Always use "powershell" — it's universally available on Windows.
# The main perf win is from eliminating nested subprocesses in the hook scripts.
$hooksBlock = @{
    "Notification" = @(
        @{
            "matcher" = ""
            "hooks" = @(
                @{
                    "type" = "command"
                    "command" = "powershell -ExecutionPolicy Bypass -NoProfile -File `"$HookDest\notification-beep.ps1`""
                    "timeout" = 5
                }
            )
        }
    )
    "Stop" = @(
        @{
            "matcher" = ""
            "hooks" = @(
                @{
                    "type" = "command"
                    "command" = "powershell -ExecutionPolicy Bypass -NoProfile -File `"$HookDest\stop-beep.ps1`""
                    "timeout" = 5
                }
            )
        }
    )
    "UserPromptSubmit" = @(
        @{
            "matcher" = ""
            "hooks" = @(
                @{
                    "type" = "command"
                    "command" = "powershell -ExecutionPolicy Bypass -NoProfile -File `"$HookDest\user-prompt-submit-beep.ps1`""
                    "timeout" = 5
                }
            )
        }
    )
}

# Register hooks in settings
Write-Info "Registering hooks in $SettingsFile..."

if (-not (Test-Path $SettingsFile)) {
    # Create new settings with hooks
    $settings = @{ "hooks" = $hooksBlock }
    $json = $settings | ConvertTo-Json -Depth 10
    Write-JsonNoBom $SettingsFile $json
    Write-Info "Created $SettingsFile with hook registrations."
} else {
    # Settings file exists - check for existing xbeep hooks
    $content = Get-Content $SettingsFile -Raw
    if ($content -match "xbeep") {
        # Remove old hooks first, then re-add (handles reinstall)
        try {
            $settings = $content | ConvertFrom-Json
            $settings = Remove-XbeepHooks $settings
            # Fall through to merge logic below
            $content = $settings | ConvertTo-Json -Depth 10
            $settings = $content | ConvertFrom-Json
            Write-Info "Replacing existing xbeep hook registrations."
        } catch {
            Write-Info "Hook registrations already present in $SettingsFile - skipping."
            $content = $null
        }
    }

    if ($content) {
        # Try to merge hooks into existing settings
        try {
            $settings = $content | ConvertFrom-Json
            # Convert to hashtable for easier manipulation
            $settingsHash = @{}
            $settings.PSObject.Properties | ForEach-Object { $settingsHash[$_.Name] = $_.Value }

            if ($settingsHash.ContainsKey("hooks")) {
                # Existing hooks - add xbeep entries
                $existingHooks = $settingsHash["hooks"]
                $existingHooksHash = @{}
                $existingHooks.PSObject.Properties | ForEach-Object { $existingHooksHash[$_.Name] = $_.Value }
                foreach ($key in $hooksBlock.Keys) {
                    $existingHooksHash[$key] = $hooksBlock[$key]
                }
                $settingsHash["hooks"] = $existingHooksHash
            } else {
                $settingsHash["hooks"] = $hooksBlock
            }

            $json = $settingsHash | ConvertTo-Json -Depth 10
            Write-JsonNoBom $SettingsFile $json
            Write-Info "Merged hook registrations into $SettingsFile."
        } catch {
            Write-Warn "Could not auto-merge into $SettingsFile."
            Write-Warn "Please add the xbeep hooks manually. See xbeep_for_windows.md for the JSON block."
        }
    }
}

# Verify
Write-Host ""
Write-Info "Installation complete!"
Write-Host ""
Write-Host "  Scripts:  $HookDest\"
Write-Host "  Command:  $CmdDest\xbeep.md"
Write-Host "  Settings: $SettingsFile"
Write-Host ""
Write-Host "  Usage (in Claude Code):"
Write-Host "    /xbeep          Toggle beep on/off"
Write-Host "    /xbeep on       Enable beeps"
Write-Host "    /xbeep off      Disable beeps"
Write-Host "    /xbeep status   Show current state"
Write-Host ""
Write-Host "  Configuration:"
Write-Host "    `$env:XBEEP_SOUND = 'C:\path\to\sound.wav'   Custom sound file"
Write-Host "    `$env:XBEEP_DEBUG = '1'                      Enable debug logging"
Write-Host ""
Write-Info "Start a new Claude Code session for hooks to take effect."
