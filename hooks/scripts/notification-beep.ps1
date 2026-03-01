# Notification Beep Hook for Claude Code (Windows)
# Beeps when Claude requests permission or needs user attention

. (Join-Path $PSScriptRoot "xbeep-common.ps1")

$DebugLog = Join-Path $env:TEMP "claude\notification-hook-debug.log"

Write-XbeepDebugLog $DebugLog "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') notification-hook ==="

# Read stdin FIRST
$input_text = [Console]::In.ReadToEnd()
Write-XbeepDebugLog $DebugLog "Input (first 300 chars): $($input_text.Substring(0, [Math]::Min(300, $input_text.Length)))"

# Check if beeping is enabled (inline — no subprocess)
if (-not (Test-XbeepEnabled)) {
    Write-XbeepDebugLog $DebugLog "Beeping DISABLED, exiting"
    exit 0
}
Write-XbeepDebugLog $DebugLog "Beeping ENABLED"

# Extract notification type for logging/future filtering
$notifType = ""
try {
    $data = $input_text | ConvertFrom-Json
    $notifType = $data.notification_type
} catch {
    Write-XbeepDebugLog $DebugLog "JSON parse error"
}
Write-XbeepDebugLog $DebugLog "Notification type: '$notifType'"

# Play the beep (all notification types beep for now)
Write-XbeepDebugLog $DebugLog "Playing beep sound (type: $notifType)"
Play-XbeepSound
Write-XbeepDebugLog $DebugLog "Notification hook completed"

exit 0
