# =============================================================================
# Tatooine Holonet - Security Check Hook (PowerShell)
# =============================================================================
# Validates tool executions before they happen.
# Blocks dangerous commands and enforces security policies.
# =============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$LogDir = ".github/hooks/logs"
$SecurityLog = "$LogDir/security.jsonl"
$StrictMode = if ($env:STRICT_MODE -eq "true") { $true } else { $false }

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

# Dangerous patterns
$CriticalPatterns = @(
    "rm -rf /",
    "del /s /q c:\",
    "format",
    "Remove-Item -Recurse -Force /",
    "DROP TABLE",
    "DROP DATABASE"
)

$SensitivePatterns = @(
    "password",
    "secret",
    "API_KEY",
    "TOKEN",
    ".env"
)

# Protected paths
$ProtectedPaths = @(
    ".env",
    ".env.local",
    ".env.production",
    "secrets/",
    "*.pem",
    "*.key"
)

# Function to deny with reason
function Deny-WithReason {
    param([string]$Reason)
    
    $output = @{
        permissionDecision = "deny"
        permissionDecisionReason = $Reason
    }
    $output | ConvertTo-Json -Compress
    exit 0
}

# Check bash/powershell commands
if ($ToolName -match "bash|shell|terminal|run_in_terminal") {
    $ArgsObj = $ToolArgs | ConvertFrom-Json
    $Command = $ArgsObj.command
    
    foreach ($pattern in $CriticalPatterns) {
        if ($Command -match [regex]::Escape($pattern)) {
            Deny-WithReason "BLOCKED: Critical security pattern detected - $pattern"
        }
    }
}

# Check file edit operations
if ($ToolName -match "edit|replace|create|write") {
    $ArgsObj = $ToolArgs | ConvertFrom-Json
    $FilePath = if ($ArgsObj.path) { $ArgsObj.path } else { $ArgsObj.filePath }
    
    foreach ($pattern in $ProtectedPaths) {
        if ($FilePath -like $pattern -or $FilePath -like "*/$pattern") {
            Deny-WithReason "BLOCKED: Cannot modify protected file - $FilePath"
        }
    }
}

# If we get here, allow the operation
exit 0
