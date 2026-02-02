#!/bin/bash
# =============================================================================
# Tatooine Holonet - Log Prompt Hook (userPromptSubmitted)
# =============================================================================
# Logs user prompts for usage analysis and debugging.
# Useful for understanding common patterns and improving workflows.
# =============================================================================

set -e

# Configuration
LOG_DIR=".github/hooks/logs"
PROMPT_LOG="${LOG_DIR}/prompts.jsonl"
STATE_FILE="${LOG_DIR}/.session-state"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Read input JSON from stdin
INPUT=$(cat)

# Parse input fields
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

# Get session ID from state file
SESSION_ID="unknown"
if [ -f "$STATE_FILE" ]; then
    SESSION_ID=$(cat "$STATE_FILE")
fi

# Convert timestamp to human-readable
if [ -n "$TIMESTAMP" ]; then
    TIMESTAMP_SEC=$((TIMESTAMP / 1000))
    HUMAN_DATE=$(date -d "@$TIMESTAMP_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$TIMESTAMP_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
else
    TIMESTAMP=$(date +%s%3N)
    HUMAN_DATE=$(date "+%Y-%m-%d %H:%M:%S")
fi

# =============================================================================
# Analyze Prompt Characteristics
# =============================================================================

# Calculate prompt length
PROMPT_LENGTH=${#PROMPT}

# Detect prompt type/intent
detect_intent() {
    local prompt="$1"
    local lower_prompt
    lower_prompt=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')
    
    if echo "$lower_prompt" | grep -qE "fix|bug|error|issue|broken|not working"; then
        echo "bugfix"
    elif echo "$lower_prompt" | grep -qE "create|add|implement|build|new"; then
        echo "feature"
    elif echo "$lower_prompt" | grep -qE "refactor|clean|improve|optimize"; then
        echo "refactor"
    elif echo "$lower_prompt" | grep -qE "explain|what|how|why|describe"; then
        echo "question"
    elif echo "$lower_prompt" | grep -qE "test|spec|coverage"; then
        echo "testing"
    elif echo "$lower_prompt" | grep -qE "document|readme|comment"; then
        echo "documentation"
    elif echo "$lower_prompt" | grep -qE "deploy|release|publish"; then
        echo "deployment"
    else
        echo "general"
    fi
}

# Detect if prompt mentions specific areas of the codebase
detect_area() {
    local prompt="$1"
    local lower_prompt
    lower_prompt=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')
    
    local areas=()
    
    if echo "$lower_prompt" | grep -qE "backend|api|fastapi|python"; then
        areas+=("backend")
    fi
    if echo "$lower_prompt" | grep -qE "frontend|next|react|ui|component"; then
        areas+=("frontend")
    fi
    if echo "$lower_prompt" | grep -qE "agent|ai|llm|smolagent|azure"; then
        areas+=("agents")
    fi
    if echo "$lower_prompt" | grep -qE "database|sql|postgres|sqlite"; then
        areas+=("database")
    fi
    if echo "$lower_prompt" | grep -qE "hook|copilot"; then
        areas+=("hooks")
    fi
    if echo "$lower_prompt" | grep -qE "docker|deploy|ci|cd|github action"; then
        areas+=("devops")
    fi
    
    if [ ${#areas[@]} -eq 0 ]; then
        echo "general"
    else
        echo "${areas[*]}" | tr ' ' ','
    fi
}

INTENT=$(detect_intent "$PROMPT")
AREA=$(detect_area "$PROMPT")

# =============================================================================
# Check for Sensitive Content
# =============================================================================

# Look for potential secrets in prompts (shouldn't be there, but warn if found)
HAS_SENSITIVE=false
if echo "$PROMPT" | grep -qiE "(password|secret|key|token|credential).*[=:].{8,}"; then
    HAS_SENSITIVE=true
fi

# =============================================================================
# Write Prompt Log Entry
# =============================================================================

# Truncate prompt to first 500 chars for log (full prompt could be very long)
TRUNCATED_PROMPT=$(echo "$PROMPT" | head -c 500)

jq -n -c \
    --arg session_id "$SESSION_ID" \
    --arg timestamp "$TIMESTAMP" \
    --arg human_date "$HUMAN_DATE" \
    --arg prompt "$TRUNCATED_PROMPT" \
    --argjson prompt_length "$PROMPT_LENGTH" \
    --arg intent "$INTENT" \
    --arg area "$AREA" \
    --argjson has_sensitive "$HAS_SENSITIVE" \
    --arg cwd "$CWD" \
    --arg user "${USER:-unknown}" \
    '{
        event: "prompt_submitted",
        session_id: $session_id,
        timestamp: ($timestamp | tonumber),
        human_date: $human_date,
        prompt: $prompt,
        prompt_length: $prompt_length,
        detected_intent: $intent,
        detected_area: $area,
        has_sensitive_content: $has_sensitive,
        cwd: $cwd,
        user: $user
    }' >> "$PROMPT_LOG"

# Warn if sensitive content detected
if [ "$HAS_SENSITIVE" = "true" ] && [ "$LOG_LEVEL" = "DEBUG" ]; then
    echo "[WARNING] Prompt may contain sensitive content" >&2
fi

exit 0
