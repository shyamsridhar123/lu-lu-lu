# =============================================================================
# Tatooine Holonet - Error Handler Hook (PowerShell)
# =============================================================================
# Handles errors that occur during agent execution.
# =============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$LogDir = ".github/hooks/logs"
$ErrorLog = "$LogDir/errors.jsonl"
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
$ErrorMessage = $Input.error.message
$ErrorName = $Input.error.name
$ErrorStack = $Input.error.stack
$Cwd = $Input.cwd

# Get session ID
$SessionId = "unknown"
if (Test-Path $StateFile) {
    $SessionId = Get-Content $StateFile -Raw
}

# Categorize error
$Category = switch -Regex ($ErrorName) {
    "Timeout" { "timeout" }
    "Network|Connection|Fetch" { "network" }
    "Auth" { "auth" }
    "Validation|Parse|Syntax" { "validation" }
    "RateLimit" { "rate_limit" }
    default { "general" }
}

$Severity = switch -Regex ($ErrorName) {
    "Memory|OutOf" { "critical" }
    "Auth" { "error" }
    default { "warning" }
}

# Get resolution hint
$Hint = switch ($Category) {
    "timeout" { "Consider increasing timeout or breaking task into smaller steps" }
    "network" { "Check network connectivity; may need to retry" }
    "auth" { "Verify API keys and credentials in .env file" }
    "rate_limit" { "Implement backoff; wait before retrying" }
    default { $null }
}

# Truncate stack
$StackPreview = if ($ErrorStack -and $ErrorStack.Length -gt 1000) { 
    $ErrorStack.Substring(0, 1000) 
} else { 
    $ErrorStack 
}

# Create log entry
$LogEntry = @{
    event = "error_occurred"
    session_id = $SessionId
    timestamp = $Timestamp
    human_date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    error = @{
        name = $ErrorName
        message = $ErrorMessage
        stack = $StackPreview
    }
    category = $Category
    severity = $Severity
    resolution_hint = $Hint
    cwd = $Cwd
    user = $env:USERNAME
}

$LogEntry | ConvertTo-Json -Compress | Add-Content -Path $ErrorLog

exit 0
