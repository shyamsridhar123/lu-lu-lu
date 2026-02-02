#!/bin/bash
# =============================================================================
# Tatooine Holonet - Session End Hook
# =============================================================================
# Executed when the Copilot coding agent session ends.
# Cleans up temporary resources, generates session summary, and archives logs.
# =============================================================================

set -e

# Configuration
LOG_DIR=".github/hooks/logs"
LOG_FILE="${LOG_DIR}/sessions.jsonl"
STATE_FILE="${LOG_DIR}/.session-state"
METRICS_FILE="${LOG_DIR}/tool-metrics.jsonl"
PROJECT_NAME="${PROJECT_NAME:-tatooine-holonet}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Read input JSON from stdin
INPUT=$(cat)

# Parse input fields
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
REASON=$(echo "$INPUT" | jq -r '.reason // "unknown"')

# Convert timestamp
if [ -n "$TIMESTAMP" ]; then
    TIMESTAMP_SEC=$((TIMESTAMP / 1000))
    HUMAN_DATE=$(date -d "@$TIMESTAMP_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -r "$TIMESTAMP_SEC" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
else
    TIMESTAMP=$(date +%s%3N)
    HUMAN_DATE=$(date "+%Y-%m-%d %H:%M:%S")
fi

# Get session ID from state file
SESSION_ID="unknown"
if [ -f "$STATE_FILE" ]; then
    SESSION_ID=$(cat "$STATE_FILE")
fi

# =============================================================================
# Calculate session metrics
# =============================================================================

# Count tool usages in this session (if metrics file exists)
TOOL_COUNT=0
TOOL_SUCCESSES=0
TOOL_FAILURES=0

if [ -f "$METRICS_FILE" ]; then
    # Get metrics for current session
    SESSION_METRICS=$(grep -F "$SESSION_ID" "$METRICS_FILE" 2>/dev/null || true)
    if [ -n "$SESSION_METRICS" ]; then
        TOOL_COUNT=$(echo "$SESSION_METRICS" | wc -l | tr -d ' ')
        TOOL_SUCCESSES=$(echo "$SESSION_METRICS" | grep -c '"success"' || true)
        TOOL_FAILURES=$(echo "$SESSION_METRICS" | grep -c '"failure"' || true)
    fi
fi

# Ensure numeric values (handle empty strings)
TOOL_COUNT=${TOOL_COUNT:-0}
TOOL_SUCCESSES=${TOOL_SUCCESSES:-0}
TOOL_FAILURES=${TOOL_FAILURES:-0}

# Convert to int (remove any whitespace)
TOOL_COUNT=$(echo "$TOOL_COUNT" | tr -d '[:space:]')
TOOL_SUCCESSES=$(echo "$TOOL_SUCCESSES" | tr -d '[:space:]')
TOOL_FAILURES=$(echo "$TOOL_FAILURES" | tr -d '[:space:]')

# Default to 0 if empty
[ -z "$TOOL_COUNT" ] && TOOL_COUNT=0
[ -z "$TOOL_SUCCESSES" ] && TOOL_SUCCESSES=0
[ -z "$TOOL_FAILURES" ] && TOOL_FAILURES=0

# =============================================================================
# Cleanup temporary resources
# =============================================================================

# Remove temporary files created during session
CLEANUP_ITEMS=0

# Clean up any .pyc files in watched directories
if [ -d "backend" ]; then
    PYCS=$(find backend -name "*.pyc" -type f 2>/dev/null | wc -l)
    if [ "$PYCS" -gt 0 ]; then
        find backend -name "*.pyc" -type f -delete 2>/dev/null || true
        CLEANUP_ITEMS=$((CLEANUP_ITEMS + PYCS))
    fi
fi

# Clean up __pycache__ directories
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# Clean up temp session files
rm -f "/tmp/copilot-session-${SESSION_ID:-*}" 2>/dev/null || true

# =============================================================================
# Generate session summary
# =============================================================================

jq -n -c \
    --arg session_id "$SESSION_ID" \
    --arg timestamp "$TIMESTAMP" \
    --arg human_date "$HUMAN_DATE" \
    --arg cwd "$CWD" \
    --arg reason "$REASON" \
    --arg project "$PROJECT_NAME" \
    --arg user "${USER:-unknown}" \
    --argjson tool_count "$TOOL_COUNT" \
    --argjson tool_successes "$TOOL_SUCCESSES" \
    --argjson tool_failures "$TOOL_FAILURES" \
    --argjson cleanup_items "$CLEANUP_ITEMS" \
    '{
        event: "session_end",
        session_id: $session_id,
        timestamp: ($timestamp | tonumber),
        human_date: $human_date,
        cwd: $cwd,
        reason: $reason,
        project: $project,
        user: $user,
        metrics: {
            total_tool_calls: $tool_count,
            successful: $tool_successes,
            failed: $tool_failures
        },
        cleanup: {
            items_removed: $cleanup_items
        }
    }' >> "$LOG_FILE"

# =============================================================================
# Archive session logs if session completed successfully
# =============================================================================

if [ "$REASON" = "complete" ] && [ "$SESSION_ID" != "unknown" ]; then
    ARCHIVE_DIR="${LOG_DIR}/archive"
    mkdir -p "$ARCHIVE_DIR"
    
    # Create session archive file
    ARCHIVE_FILE="${ARCHIVE_DIR}/${SESSION_ID}.json"
    
    # Extract all events for this session
    {
        echo "{"
        echo "  \"session_id\": \"$SESSION_ID\","
        echo "  \"completed_at\": \"$HUMAN_DATE\","
        echo "  \"reason\": \"$REASON\","
        echo "  \"events\": ["
        grep -F "$SESSION_ID" "$LOG_FILE" 2>/dev/null | sed 's/^/    /' | paste -sd ',' -
        echo "  ]"
        echo "}"
    } > "$ARCHIVE_FILE" 2>/dev/null || true
fi

# Remove session state file
rm -f "$STATE_FILE" 2>/dev/null || true

exit 0
