# Beep State Management for Claude Code Hooks (Windows)
# CLI wrapper around shared state functions in xbeep-common.ps1

param(
    [Parameter(Position = 0)]
    [string]$Command = ""
)

. (Join-Path $PSScriptRoot "xbeep-common.ps1")

switch ($Command) {
    "check" {
        # Silent check for hooks — exit code only
        if (Test-XbeepEnabled) { exit 0 } else { exit 1 }
    }
    default {
        $result = Invoke-XbeepCommand $Command
        Write-Output $result
        # Exit 1 for unknown commands (help text)
        if ($Command -and $Command -notin "enable","on","disable","off","status","toggle") {
            exit 1
        }
    }
}
