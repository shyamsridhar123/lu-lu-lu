# =============================================================================
# Tatooine Holonet - Post Tool Metrics Hook (PowerShell)
# =============================================================================
# Records tool execution results for performance monitoring.
# =============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$LogDir = ".github/hooks/logs"
$MetricsLog = "$LogDir/tool-metrics.jsonl"
$StatsFile = "$LogDir/daily-stats.csv"
$StateFile = "$LogDir/.session-state"

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Read input JSON from stdin
$InputText = [Console]::In.ReadToEnd()
$Input = $InputText | ConvertFrom-Json

# Parse input fields
$Timestamp = $Input.timestamp
$ToolName = $Input.toolName
$ToolArgs = $Input.toolArgs
$ResultType = $Input.toolResult.resultType
$ResultText = $Input.toolResult.textResultForLlm
$Cwd = $Input.cwd

# Get session ID
$SessionId = "unknown"
if (Test-Path $StateFile) {
    $SessionId = Get-Content $StateFile -Raw
}

# Determine severity
$Severity = switch ($ResultType) {
    "failure" { "error" }
    "denied" { "warning" }
    default { "info" }
}

# Truncate result text
$ResultPreview = if ($ResultText.Length -gt 500) { $ResultText.Substring(0, 500) } else { $ResultText }

# Create log entry
$LogEntry = @{
    event = "tool_result"
    session_id = $SessionId
    timestamp = $Timestamp
    human_date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    tool = $ToolName
    result_type = $ResultType
    severity = $Severity
    result_preview = $ResultPreview
    cwd = $Cwd
    user = $env:USERNAME
}

$LogEntry | ConvertTo-Json -Compress | Add-Content -Path $MetricsLog

# Update daily stats
if (-not (Test-Path $StatsFile)) {
    "date,tool,success,failure,denied" | Out-File -FilePath $StatsFile
}

$DayDate = Get-Date -Format "yyyy-MM-dd"
$Success = if ($ResultType -eq "success") { 1 } else { 0 }
$Failure = if ($ResultType -eq "failure") { 1 } else { 0 }
$Denied = if ($ResultType -eq "denied") { 1 } else { 0 }

"$DayDate,$ToolName,$Success,$Failure,$Denied" | Add-Content -Path $StatsFile

exit 0
