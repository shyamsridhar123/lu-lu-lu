#!/bin/bash
# =============================================================================
# Tatooine Holonet - Session Start Hook
# =============================================================================
# Executed when a new Copilot coding agent session begins or resumes.
# Initializes environment, validates project state, and logs session start.
# =============================================================================

set -e

# Configuration
LOG_DIR=".github/hooks/logs"
LOG_FILE="${LOG_DIR}/sessions.jsonl"
STATE_FILE="${LOG_DIR}/.session-state"
PROJECT_NAME="${PROJECT_NAME:-tatooine-holonet}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Read input JSON from stdin
INPUT=$(cat)

# Parse input fields using jq
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
SOURCE=$(echo "$INPUT" | jq -r '.source // "unknown"')
INITIAL_PROMPT=$(echo "$INPUT" | jq -r '.initialPrompt // empty')

# Convert timestamp to human-readable format
if [ -n "$TIMESTAMP" ]; then
    TIMESTAMP_SEC=$((TIMESTAMP / 1000))
    HUMAN_DATE=$(date -d "@$TIMESTAMP_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$TIMESTAMP_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
else
    TIMESTAMP=$(date +%s%3N)
    HUMAN_DATE=$(date "+%Y-%m-%d %H:%M:%S")
fi

# Generate session ID
SESSION_ID="session-$(date +%Y%m%d-%H%M%S)-$$"

# Store session state for other hooks
echo "$SESSION_ID" > "$STATE_FILE"

# Initialize validation warnings array
VALIDATION_WARNINGS=()

# =============================================================================
# Agent & Skill Compliance Validation
# =============================================================================

# Run compliance validation (non-blocking, just log warnings)
COMPLIANCE_SCRIPT=".github/hooks/scripts/validate-compliance.sh"
if [ -f "$COMPLIANCE_SCRIPT" ] && [ -x "$COMPLIANCE_SCRIPT" ]; then
    if ! "$COMPLIANCE_SCRIPT" > /dev/null 2>&1; then
        VALIDATION_WARNINGS+=("Agent/Skill compliance check failed - run validate-compliance.sh for details")
    fi
fi

# =============================================================================
# Project-specific validations for Tatooine Holonet
# =============================================================================

# Check for required configuration files

# Check package.json exists
if [ ! -f "package.json" ]; then
    VALIDATION_WARNINGS+=("package.json not found")
fi

# Check for AGENTS.md enforcement document
if [ ! -f "AGENTS.md" ]; then
    VALIDATION_WARNINGS+=("AGENTS.md enforcement document not found")
fi

# Check for copilot-instructions.md
if [ ! -f ".github/copilot-instructions.md" ]; then
    VALIDATION_WARNINGS+=(".github/copilot-instructions.md not found")
fi

# Check for .env file (warn but don't block)
if [ ! -f ".env" ] && [ ! -f "backend/.env" ]; then
    VALIDATION_WARNINGS+=(".env file not found - Azure AI credentials may be missing")
fi

# Check for Python virtual environment
if [ -d "backend" ] && [ ! -d "backend/venv" ] && [ ! -d "backend/.venv" ]; then
    VALIDATION_WARNINGS+=("Python virtual environment not found in backend/")
fi

# Check Node modules
if [ -d "frontend" ] && [ ! -d "frontend/node_modules" ]; then
    VALIDATION_WARNINGS+=("frontend/node_modules not found - run npm install")
fi

# =============================================================================
# Log session start
# =============================================================================

# Build warnings JSON array
WARNINGS_JSON="[]"
if [ ${#VALIDATION_WARNINGS[@]} -gt 0 ]; then
    WARNINGS_JSON=$(printf '%s\n' "${VALIDATION_WARNINGS[@]}" | jq -R . | jq -s .)
fi

# Create structured log entry
jq -n -c \
    --arg session_id "$SESSION_ID" \
    --arg timestamp "$TIMESTAMP" \
    --arg human_date "$HUMAN_DATE" \
    --arg cwd "$CWD" \
    --arg source "$SOURCE" \
    --arg initial_prompt "$INITIAL_PROMPT" \
    --arg project "$PROJECT_NAME" \
    --arg user "${USER:-unknown}" \
    --argjson warnings "$WARNINGS_JSON" \
    '{
        event: "session_start",
        session_id: $session_id,
        timestamp: ($timestamp | tonumber),
        human_date: $human_date,
        cwd: $cwd,
        source: $source,
        initial_prompt: (if $initial_prompt == "" then null else $initial_prompt end),
        project: $project,
        user: $user,
        validation_warnings: $warnings
    }' >> "$LOG_FILE"

# Print summary if LOG_LEVEL is DEBUG
if [ "$LOG_LEVEL" = "DEBUG" ]; then
    echo "[DEBUG] Session started: $SESSION_ID (source: $SOURCE)" >&2
    if [ ${#VALIDATION_WARNINGS[@]} -gt 0 ]; then
        echo "[DEBUG] Warnings: ${VALIDATION_WARNINGS[*]}" >&2
    fi
fi

exit 0
