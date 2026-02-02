#!/bin/bash
# =============================================================================
# Tatooine Holonet - Security Check Hook (preToolUse)
# =============================================================================
# Validates tool executions before they happen.
# Blocks dangerous commands, enforces file access policies, and prevents
# credential leaks.
#
# This is the most powerful hook - it can DENY tool executions.
# =============================================================================

set -e

# Configuration
LOG_DIR=".github/hooks/logs"
SECURITY_LOG="${LOG_DIR}/security.jsonl"
STRICT_MODE="${STRICT_MODE:-true}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Read input JSON from stdin
INPUT=$(cat)

# Parse input fields
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // empty')
TOOL_ARGS=$(echo "$INPUT" | jq -r '.toolArgs // "{}"')

# =============================================================================
# Dangerous Command Patterns
# =============================================================================

# Patterns that should ALWAYS be blocked
CRITICAL_PATTERNS=(
    "rm -rf /"
    "rm -rf /*"
    "mkfs"
    "> /dev/sd"
    "dd if=/dev/zero"
    ":(){ :|:& };:"  # Fork bomb
    "chmod -R 777 /"
    "wget.*|.*sh"    # Piping remote scripts
    "curl.*|.*sh"
    "eval \$("
    "base64 -d.*|.*sh"
)

# Patterns that require extra scrutiny
SENSITIVE_PATTERNS=(
    "sudo"
    "su -"
    "passwd"
    "chown -R"
    "chmod -R"
    "DROP TABLE"
    "DROP DATABASE"
    "TRUNCATE"
    "DELETE FROM.*WHERE 1=1"
    "/etc/passwd"
    "/etc/shadow"
    ".ssh/id_rsa"
    "AWS_SECRET"
    "AZURE_.*_KEY"
    "OPENAI_API_KEY"
    "HF_TOKEN"
    "authorization.*bearer"
    "npm publish"
    "pip upload"
    "git push.*--force"
    "git push.*-f"
)

# =============================================================================
# Protected Paths
# =============================================================================

PROTECTED_PATHS=(
    ".env"
    ".env.local"
    ".env.production"
    "secrets/"
    "credentials/"
    ".ssh/"
    ".gnupg/"
    ".aws/"
    "*.pem"
    "*.key"
    "*_rsa"
)

# =============================================================================
# Security Check Functions
# =============================================================================

log_security_event() {
    local severity="$1"
    local message="$2"
    local decision="$3"
    
    jq -n -c \
        --arg timestamp "$TIMESTAMP" \
        --arg tool "$TOOL_NAME" \
        --arg severity "$severity" \
        --arg message "$message" \
        --arg decision "$decision" \
        --arg args "$TOOL_ARGS" \
        '{
            event: "security_check",
            timestamp: ($timestamp | tonumber),
            tool: $tool,
            severity: $severity,
            message: $message,
            decision: $decision,
            tool_args: $args
        }' >> "$SECURITY_LOG"
}

deny_with_reason() {
    local reason="$1"
    log_security_event "CRITICAL" "$reason" "denied"
    echo "{\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$reason\"}" | jq -c
    exit 0
}

# =============================================================================
# Tool-specific Security Checks
# =============================================================================

check_bash_command() {
    local command
    command=$(echo "$TOOL_ARGS" | jq -r '.command // empty')
    
    if [ -z "$command" ]; then
        return 0
    fi
    
    # Check critical patterns
    for pattern in "${CRITICAL_PATTERNS[@]}"; do
        if echo "$command" | grep -qiE "$pattern"; then
            deny_with_reason "BLOCKED: Critical security pattern detected - $pattern"
        fi
    done
    
    # Check sensitive patterns in strict mode
    if [ "$STRICT_MODE" = "true" ]; then
        for pattern in "${SENSITIVE_PATTERNS[@]}"; do
            if echo "$command" | grep -qiE "$pattern"; then
                log_security_event "WARNING" "Sensitive pattern detected: $pattern" "flagged"
                # In strict mode, we flag but allow - change to deny_with_reason to block
            fi
        done
    fi
    
    # Check for secret exposure in echo/printf commands
    if echo "$command" | grep -qE "^(echo|printf).*\\\$[A-Z_]*(KEY|SECRET|TOKEN|PASSWORD|PASS|CREDENTIAL)"; then
        log_security_event "WARNING" "Potential secret exposure in output" "flagged"
    fi
}

check_edit_operation() {
    local file_path
    file_path=$(echo "$TOOL_ARGS" | jq -r '.path // .filePath // empty')
    
    if [ -z "$file_path" ]; then
        return 0
    fi
    
    # Check protected paths
    for pattern in "${PROTECTED_PATHS[@]}"; do
        if [[ "$file_path" == $pattern ]] || [[ "$file_path" == *"/$pattern" ]]; then
            deny_with_reason "BLOCKED: Cannot modify protected file - $file_path"
        fi
    done
    
    # Warn about environment files but allow in development
    if [[ "$file_path" == *".env"* ]]; then
        log_security_event "WARNING" "Editing environment file: $file_path" "flagged"
    fi
}

check_create_operation() {
    local file_path
    file_path=$(echo "$TOOL_ARGS" | jq -r '.path // .filePath // empty')
    
    if [ -z "$file_path" ]; then
        return 0
    fi
    
    # Block creating files in sensitive directories
    if [[ "$file_path" == /etc/* ]] || [[ "$file_path" == /usr/* ]] || [[ "$file_path" == ~/.ssh/* ]]; then
        deny_with_reason "BLOCKED: Cannot create files in system directories"
    fi
}

# =============================================================================
# Main Security Check Logic
# =============================================================================

case "$TOOL_NAME" in
    "bash"|"shell"|"terminal"|"run_in_terminal")
        check_bash_command
        ;;
    "edit"|"replace"|"replace_string_in_file"|"multi_replace_string_in_file")
        check_edit_operation
        ;;
    "create"|"create_file"|"write_file")
        check_edit_operation
        check_create_operation
        ;;
    "read"|"read_file"|"view")
        # Allow reads but log access to sensitive files
        file_path=$(echo "$TOOL_ARGS" | jq -r '.path // .filePath // empty')
        for pattern in "${PROTECTED_PATHS[@]}"; do
            if [[ "$file_path" == $pattern ]] || [[ "$file_path" == *"/$pattern" ]]; then
                log_security_event "INFO" "Reading sensitive file: $file_path" "allowed"
            fi
        done
        ;;
    *)
        # Allow other tools by default
        ;;
esac

# If we get here, the tool is allowed
exit 0
