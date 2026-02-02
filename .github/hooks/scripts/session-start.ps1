# =============================================================================
# Tatooine Holonet - Session Start Hook (PowerShell)
# =============================================================================
# Executed when a new Copilot coding agent session begins or resumes.
# =============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$LogDir = ".github/hooks/logs"
$LogFile = "$LogDir/sessions.jsonl"
$StateFile = "$LogDir/.session-state"
$ProjectName = if ($env:PROJECT_NAME) { $env:PROJECT_NAME } else { "tatooine-holonet" }

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
$Source = if ($Input.source) { $Input.source } else { "unknown" }
$InitialPrompt = $Input.initialPrompt

# Generate session ID
$SessionId = "session-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$PID"

# Store session state
$SessionId | Out-File -FilePath $StateFile -NoNewline

# Validation warnings
$ValidationWarnings = @()

if (-not (Test-Path "package.json")) {
    $ValidationWarnings += "package.json not found"
}

if (-not (Test-Path ".env") -and -not (Test-Path "backend/.env")) {
    $ValidationWarnings += ".env file not found - Azure AI credentials may be missing"
}

# Create log entry
$LogEntry = @{
    event = "session_start"
    session_id = $SessionId
    timestamp = $Timestamp
    human_date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    cwd = $Cwd
    source = $Source
    initial_prompt = $InitialPrompt
    project = $ProjectName
    user = $env:USERNAME
    validation_warnings = $ValidationWarnings
}

$LogEntry | ConvertTo-Json -Compress | Add-Content -Path $LogFile

exit 0
