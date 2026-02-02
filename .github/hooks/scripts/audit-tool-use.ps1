# =============================================================================
# Tatooine Holonet - Audit Tool Use Hook (PowerShell)
# =============================================================================
# Logs all tool executions for compliance and debugging.
# =============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$LogDir = ".github/hooks/logs"
$AuditLog = "$LogDir/audit.jsonl"
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
$Cwd = $Input.cwd

# Get session ID
$SessionId = "unknown"
if (Test-Path $StateFile) {
    $SessionId = Get-Content $StateFile -Raw
}

# Categorize tool
$Category = switch -Regex ($ToolName) {
    "bash|shell|terminal" { "execution" }
    "read|view|grep" { "read" }
    "edit|replace|create|write" { "write" }
    "list|find" { "navigation" }
    "git|github" { "vcs" }
    "search" { "search" }
    default { "other" }
}

# Create log entry
$LogEntry = @{
    event = "tool_audit"
    session_id = $SessionId
    timestamp = $Timestamp
    human_date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    tool = $ToolName
    category = $Category
    cwd = $Cwd
    user = $env:USERNAME
    phase = "pre"
}

$LogEntry | ConvertTo-Json -Compress | Add-Content -Path $AuditLog

exit 0
