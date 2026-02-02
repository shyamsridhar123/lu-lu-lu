# =============================================================================
# Tatooine Holonet - Log Prompt Hook (PowerShell)
# =============================================================================
# Logs user prompts for usage analysis.
# =============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$LogDir = ".github/hooks/logs"
$PromptLog = "$LogDir/prompts.jsonl"
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
$Prompt = $Input.prompt
$Cwd = $Input.cwd

# Get session ID
$SessionId = "unknown"
if (Test-Path $StateFile) {
    $SessionId = Get-Content $StateFile -Raw
}

# Detect intent
$Intent = switch -Regex ($Prompt.ToLower()) {
    "fix|bug|error|issue" { "bugfix" }
    "create|add|implement|build|new" { "feature" }
    "refactor|clean|improve" { "refactor" }
    "explain|what|how|why" { "question" }
    "test|spec|coverage" { "testing" }
    "document|readme" { "documentation" }
    default { "general" }
}

# Truncate prompt
$TruncatedPrompt = if ($Prompt.Length -gt 500) { $Prompt.Substring(0, 500) } else { $Prompt }

# Create log entry
$LogEntry = @{
    event = "prompt_submitted"
    session_id = $SessionId
    timestamp = $Timestamp
    human_date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    prompt = $TruncatedPrompt
    prompt_length = $Prompt.Length
    detected_intent = $Intent
    cwd = $Cwd
    user = $env:USERNAME
}

$LogEntry | ConvertTo-Json -Compress | Add-Content -Path $PromptLog

exit 0
