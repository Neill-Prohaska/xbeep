# Stop Beep Hook for Claude Code (Windows)
# Beeps when Claude finishes responding and is waiting for next input

. (Join-Path $PSScriptRoot "xbeep-common.ps1")

$DebugLog = Join-Path $env:TEMP "claude\stop-hook-debug.log"

Write-XbeepDebugLog $DebugLog "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') stop-hook ==="

# Read stdin FIRST (before any other calls)
$input_text = [Console]::In.ReadToEnd()
Write-XbeepDebugLog $DebugLog "Input (first 300 chars): $($input_text.Substring(0, [Math]::Min(300, $input_text.Length)))"

# Check if beeping is enabled (inline — no subprocess)
if (-not (Test-XbeepEnabled)) {
    Write-XbeepDebugLog $DebugLog "Beeping DISABLED, exiting"
    exit 0
}
Write-XbeepDebugLog $DebugLog "Beeping ENABLED"

# Loop prevention: extract the specific stop_hook_active field value
try {
    $data = $input_text | ConvertFrom-Json
    if ($data.stop_hook_active -eq $true) {
        Write-XbeepDebugLog $DebugLog "stop_hook_active=true, preventing loop"
        exit 0
    }
} catch {
    Write-XbeepDebugLog $DebugLog "JSON parse error, continuing anyway"
}

# Play the beep
Write-XbeepDebugLog $DebugLog "Playing beep sound"
Play-XbeepSound
Write-XbeepDebugLog $DebugLog "Stop hook completed"

exit 0
