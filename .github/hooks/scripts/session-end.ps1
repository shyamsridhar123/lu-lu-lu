# =============================================================================
# Tatooine Holonet - Session End Hook (PowerShell)
# =============================================================================
# Executed when the Copilot coding agent session ends.
# =============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$LogDir = ".github/hooks/logs"
$LogFile = "$LogDir/sessions.jsonl"
$StateFile = "$LogDir/.session-state"
$MetricsFile = "$LogDir/tool-metrics.jsonl"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Read input JSON from stdin
$InputText = [Console]::In.ReadToEnd()
$Input = $InputText | ConvertFrom-Json

# Parse input fields
$Timestamp = if ($Input.timestamp) { $Input.timestamp } else { [DateTimeOffset]::Now.ToUnixTimeMilliseconds() }
$Cwd = if ($Input.cwd) { $Input.cwd } else { Get-Location }
$Reason = if ($Input.reason) { $Input.reason } else { "unknown" }

# Get session ID from state file
$SessionId = "unknown"
if (Test-Path $StateFile) {
    $SessionId = Get-Content $StateFile -Raw
}

# Count metrics
$ToolCount = 0
$ToolSuccesses = 0
$ToolFailures = 0

if (Test-Path $MetricsFile) {
    $Metrics = Get-Content $MetricsFile | Where-Object { $_ -match $SessionId }
    $ToolCount = $Metrics.Count
    $ToolSuccesses = ($Metrics | Where-Object { $_ -match '"success"' }).Count
    $ToolFailures = ($Metrics | Where-Object { $_ -match '"failure"' }).Count
}

# Create log entry
$LogEntry = @{
    event = "session_end"
    session_id = $SessionId
    timestamp = $Timestamp
    human_date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    cwd = $Cwd
    reason = $Reason
    user = $env:USERNAME
    metrics = @{
        total_tool_calls = $ToolCount
        successful = $ToolSuccesses
        failed = $ToolFailures
    }
}

$LogEntry | ConvertTo-Json -Compress | Add-Content -Path $LogFile

# Cleanup state file
if (Test-Path $StateFile) {
    Remove-Item $StateFile -Force
}

exit 0
