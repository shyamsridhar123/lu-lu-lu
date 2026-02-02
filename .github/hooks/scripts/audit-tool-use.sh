#!/bin/bash
# =============================================================================
# Tatooine Holonet - Audit Tool Use Hook (preToolUse)
# =============================================================================
# Logs all tool executions for compliance, debugging, and usage analysis.
# Runs after security-check.sh in the preToolUse hooks chain.
# =============================================================================

set -e

# Configuration
LOG_DIR=".github/hooks/logs"
AUDIT_LOG="${LOG_DIR}/audit.jsonl"
STATE_FILE="${LOG_DIR}/.session-state"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Read input JSON from stdin
INPUT=$(cat)

# Parse input fields
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.toolName // empty')
TOOL_ARGS=$(echo "$INPUT" | jq -r '.toolArgs // "{}"')

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
# Categorize Tool Usage
# =============================================================================

categorize_tool() {
    local tool="$1"
    case "$tool" in
        "bash"|"shell"|"terminal"|"run_in_terminal")
            echo "execution"
            ;;
        "read"|"read_file"|"view"|"grep"|"search")
            echo "read"
            ;;
        "edit"|"replace"|"create"|"write"|"create_file"|"replace_string_in_file"|"multi_replace_string_in_file")
            echo "write"
            ;;
        "list"|"list_dir"|"find"|"ls")
            echo "navigation"
            ;;
        "git"|"github")
            echo "vcs"
            ;;
        "semantic_search"|"grep_search"|"file_search")
            echo "search"
            ;;
        *)
            echo "other"
            ;;
    esac
}

# =============================================================================
# Extract relevant info from tool args
# =============================================================================

extract_target() {
    local args="$1"
    local tool="$2"
    
    case "$tool" in
        "bash"|"shell"|"terminal"|"run_in_terminal")
            echo "$args" | jq -r '.command // .cmd // empty' | head -c 100
            ;;
        "read"|"read_file"|"view"|"edit"|"create"|"write"|"create_file"|"replace_string_in_file")
            echo "$args" | jq -r '.path // .filePath // empty'
            ;;
        "list"|"list_dir")
            echo "$args" | jq -r '.path // .directory // empty'
            ;;
        "grep"|"grep_search"|"search")
            echo "$args" | jq -r '.query // .pattern // empty' | head -c 100
            ;;
        *)
            echo ""
            ;;
    esac
}

CATEGORY=$(categorize_tool "$TOOL_NAME")
TARGET=$(extract_target "$TOOL_ARGS" "$TOOL_NAME")

# =============================================================================
# Write Audit Log Entry
# =============================================================================

jq -n -c \
    --arg session_id "$SESSION_ID" \
    --arg timestamp "$TIMESTAMP" \
    --arg human_date "$HUMAN_DATE" \
    --arg tool "$TOOL_NAME" \
    --arg category "$CATEGORY" \
    --arg target "$TARGET" \
    --arg cwd "$CWD" \
    --arg user "${USER:-unknown}" \
    --arg phase "pre" \
    '{
        event: "tool_audit",
        session_id: $session_id,
        timestamp: ($timestamp | tonumber),
        human_date: $human_date,
        tool: $tool,
        category: $category,
        target: $target,
        cwd: $cwd,
        user: $user,
        phase: $phase
    }' >> "$AUDIT_LOG"

# Do not output anything - this hook only logs, doesn't make decisions
exit 0
