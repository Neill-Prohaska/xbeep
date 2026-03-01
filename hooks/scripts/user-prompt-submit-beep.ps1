# User Prompt Submit Hook for Claude Code xbeep (Windows)
# Intercepts /xbeep commands to manage beep state
# Exit 0 = pass through, Exit 2 = block prompt (command handled here)

. (Join-Path $PSScriptRoot "xbeep-common.ps1")

$DebugLog = Join-Path $env:TEMP "claude\hook-debug.log"

Write-XbeepDebugLog $DebugLog "=== $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') user-prompt-submit ==="

# Read stdin
$input_text = [Console]::In.ReadToEnd()
Write-XbeepDebugLog $DebugLog "Input (first 200 chars): $($input_text.Substring(0, [Math]::Min(200, $input_text.Length)))"

# Check for /xbeep command
try {
    $data = $input_text | ConvertFrom-Json
    $prompt = $data.prompt

    if ($prompt -match '^/xbeep') {
        Write-XbeepDebugLog $DebugLog "Extracted prompt: '$prompt'"

        # Extract argument after /xbeep
        $arg = ""
        if ($prompt -match '^/xbeep\s+(.+)$') {
            $arg = $Matches[1].Trim()
        }
        Write-XbeepDebugLog $DebugLog "Argument: '$arg'"

        # Call state function directly (no subprocess)
        $output = Invoke-XbeepCommand $arg
        Write-XbeepDebugLog $DebugLog "Output: $output"

        # Send output to stderr so user sees it
        [Console]::Error.WriteLine($output)

        # Exit 2 to block the prompt from reaching Claude
        exit 2
    }
} catch {
    Write-XbeepDebugLog $DebugLog "JSON parse error: $_"
}

Write-XbeepDebugLog $DebugLog "Not /xbeep, passing through"
exit 0
