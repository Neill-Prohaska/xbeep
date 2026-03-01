# xbeep shared functions for Claude Code hooks (Windows)
# Dot-source this file from hook scripts: . (Join-Path $PSScriptRoot "xbeep-common.ps1")

# --- Session-isolated state file ---

function Get-XbeepSessionId {
    try {
        # Fast path: PowerShell 7+ (.NET 5+)
        $parent = (Get-Process -Id $PID).Parent
        if ($parent) { return $parent.Id }
    } catch {}
    try {
        # Fallback: WMI (Windows PowerShell 5.1)
        return (Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId
    } catch {}
    return "session"
}

function Get-XbeepStateFile {
    $sessionId = Get-XbeepSessionId
    return (Join-Path $env:TEMP "claude_beep_enabled_$sessionId")
}

# --- State management ---

function Test-XbeepEnabled {
    $stateFile = Get-XbeepStateFile
    if (Test-Path $stateFile) {
        $content = Get-Content $stateFile -Raw -ErrorAction SilentlyContinue
        if ($content -match "disabled") { return $false }
    }
    return $true
}

function Enable-Xbeep {
    "enabled" | Set-Content (Get-XbeepStateFile) -NoNewline
    return "Beep notifications enabled for this session."
}

function Disable-Xbeep {
    "disabled" | Set-Content (Get-XbeepStateFile) -NoNewline
    return "Beep notifications disabled for this session."
}

function Show-XbeepStatus {
    if (Test-XbeepEnabled) {
        return "Beep notifications: ENABLED (default: on)"
    } else {
        return "Beep notifications: DISABLED (default: on)"
    }
}

function Toggle-Xbeep {
    if (Test-XbeepEnabled) { Disable-Xbeep } else { Enable-Xbeep }
}

function Invoke-XbeepCommand {
    param([string]$Command = "")
    switch ($Command) {
        { $_ -in "enable", "on" } { Enable-Xbeep }
        { $_ -in "disable", "off" } { Disable-Xbeep }
        "status" { Show-XbeepStatus }
        "check" {
            if (Test-XbeepEnabled) { return "enabled" } else { return "disabled" }
        }
        { $_ -in "toggle", "" } { Toggle-Xbeep }
        default {
            return "Usage: /xbeep [on|off|status|toggle]"
        }
    }
}

# --- Debug logging ---

function Write-XbeepDebugLog {
    param([string]$LogFile, [string]$Message)
    if ($env:XBEEP_DEBUG -eq "1") {
        $dir = Split-Path $LogFile -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $LogFile -Value $Message
    }
}

# --- Sound playback ---

function Play-XbeepSound {
    # Priority: XBEEP_SOUND env var > bundled WAV > Console::Beep fallback
    $soundFile = $null
    if ($env:XBEEP_SOUND -and (Test-Path $env:XBEEP_SOUND)) {
        $soundFile = $env:XBEEP_SOUND
    } else {
        $bundled = Join-Path $PSScriptRoot "universfield-ping.wav"
        if (Test-Path $bundled) { $soundFile = $bundled }
    }

    if ($soundFile) {
        try {
            $player = New-Object System.Media.SoundPlayer $soundFile
            $player.PlaySync()
            return
        } catch {}
    }
    # Final fallback: always audible regardless of Windows sound scheme
    [Console]::Beep(800, 200)
}
