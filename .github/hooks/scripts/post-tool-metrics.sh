#!/bin/bash
# =============================================================================
# Tatooine Holonet - Post Tool Metrics Hook (postToolUse)
# =============================================================================
# Records tool execution results for performance monitoring and debugging.
# Tracks success/failure rates, patterns, and generates alerts on failures.
# =============================================================================

set -e

# Configuration
LOG_DIR=".github/hooks/logs"
METRICS_LOG="${LOG_DIR}/tool-metrics.jsonl"
STATS_FILE="${LOG_DIR}/daily-stats.csv"
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

# Parse tool result
RESULT_TYPE=$(echo "$INPUT" | jq -r '.toolResult.resultType // "unknown"')
RESULT_TEXT=$(echo "$INPUT" | jq -r '.toolResult.textResultForLlm // empty' | head -c 500)

# Get session ID from state file
SESSION_ID="unknown"
if [ -f "$STATE_FILE" ]; then
    SESSION_ID=$(cat "$STATE_FILE")
fi

# Convert timestamp to human-readable
if [ -n "$TIMESTAMP" ]; then
    TIMESTAMP_SEC=$((TIMESTAMP / 1000))
    HUMAN_DATE=$(date -d "@$TIMESTAMP_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$TIMESTAMP_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
    DAY_DATE=$(date -d "@$TIMESTAMP_SEC" "+%Y-%m-%d" 2>/dev/null || date -r "$TIMESTAMP_SEC" "+%Y-%m-%d" 2>/dev/null || echo "unknown")
else
    TIMESTAMP=$(date +%s%3N)
    HUMAN_DATE=$(date "+%Y-%m-%d %H:%M:%S")
    DAY_DATE=$(date "+%Y-%m-%d")
fi

# =============================================================================
# Analyze Result
# =============================================================================

# Determine if result indicates an issue
analyze_result() {
    local result_type="$1"
    local result_text="$2"
    local tool="$3"
    
    local severity="info"
    local issue=""
    
    if [ "$result_type" = "failure" ]; then
        severity="error"
        
        # Try to categorize the error
        if echo "$result_text" | grep -qiE "permission denied|access denied|unauthorized"; then
            issue="permission_error"
        elif echo "$result_text" | grep -qiE "not found|no such file|does not exist"; then
            issue="not_found"
        elif echo "$result_text" | grep -qiE "timeout|timed out"; then
            issue="timeout"
        elif echo "$result_text" | grep -qiE "syntax error|parse error"; then
            issue="syntax_error"
        elif echo "$result_text" | grep -qiE "connection|network|socket"; then
            issue="network_error"
        elif echo "$result_text" | grep -qiE "out of memory|memory"; then
            issue="memory_error"
        else
            issue="unknown_error"
        fi
    elif [ "$result_type" = "denied" ]; then
        severity="warning"
        issue="security_denied"
    fi
    
    echo "$severity|$issue"
}

ANALYSIS=$(analyze_result "$RESULT_TYPE" "$RESULT_TEXT" "$TOOL_NAME")
SEVERITY=$(echo "$ANALYSIS" | cut -d'|' -f1)
ISSUE_TYPE=$(echo "$ANALYSIS" | cut -d'|' -f2)

# =============================================================================
# Write Metrics Log Entry
# =============================================================================

jq -n -c \
    --arg session_id "$SESSION_ID" \
    --arg timestamp "$TIMESTAMP" \
    --arg human_date "$HUMAN_DATE" \
    --arg tool "$TOOL_NAME" \
    --arg result_type "$RESULT_TYPE" \
    --arg severity "$SEVERITY" \
    --arg issue_type "$ISSUE_TYPE" \
    --arg result_preview "$RESULT_TEXT" \
    --arg cwd "$CWD" \
    --arg user "${USER:-unknown}" \
    '{
        event: "tool_result",
        session_id: $session_id,
        timestamp: ($timestamp | tonumber),
        human_date: $human_date,
        tool: $tool,
        result_type: $result_type,
        severity: $severity,
        issue_type: (if $issue_type == "" then null else $issue_type end),
        result_preview: $result_preview,
        cwd: $cwd,
        user: $user
    }' >> "$METRICS_LOG"

# =============================================================================
# Update Daily Statistics
# =============================================================================

# Initialize stats file if needed
if [ ! -f "$STATS_FILE" ]; then
    echo "date,tool,success,failure,denied" > "$STATS_FILE"
fi

# Append to daily stats (simple CSV for quick analysis)
SUCCESS=$( [ "$RESULT_TYPE" = "success" ] && echo 1 || echo 0 )
FAILURE=$( [ "$RESULT_TYPE" = "failure" ] && echo 1 || echo 0 )
DENIED=$( [ "$RESULT_TYPE" = "denied" ] && echo 1 || echo 0 )

echo "$DAY_DATE,$TOOL_NAME,$SUCCESS,$FAILURE,$DENIED" >> "$STATS_FILE"

# =============================================================================
# Track Consecutive Failures (for alerts)
# =============================================================================

FAILURE_TRACKER="${LOG_DIR}/.failure-tracker"

if [ "$RESULT_TYPE" = "failure" ]; then
    # Increment failure count
    if [ -f "$FAILURE_TRACKER" ]; then
        FAIL_COUNT=$(cat "$FAILURE_TRACKER")
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        FAIL_COUNT=1
    fi
    echo "$FAIL_COUNT" > "$FAILURE_TRACKER"
    
    # Log warning if too many consecutive failures (could trigger alert)
    if [ "$FAIL_COUNT" -ge 5 ]; then
        jq -n -c \
            --arg session_id "$SESSION_ID" \
            --arg timestamp "$TIMESTAMP" \
            --argjson count "$FAIL_COUNT" \
            '{
                event: "consecutive_failures_alert",
                session_id: $session_id,
                timestamp: ($timestamp | tonumber),
                failure_count: $count,
                message: "Multiple consecutive tool failures detected"
            }' >> "$METRICS_LOG"
    fi
else
    # Reset failure counter on success
    rm -f "$FAILURE_TRACKER" 2>/dev/null || true
fi

exit 0
